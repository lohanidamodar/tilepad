import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Splits a manifest `run` command into an executable and its arguments.
///
/// Supports simple double-quoted segments so paths with spaces work, e.g.
/// `"C:\My Tools\node.exe" plugin.js`.
List<String> parseRunCommand(String command) {
  final tokens = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < command.length; i++) {
    final ch = command[i];
    if (ch == '"') {
      inQuotes = !inQuotes;
    } else if (ch == ' ' && !inQuotes) {
      if (buf.isNotEmpty) {
        tokens.add(buf.toString());
        buf.clear();
      }
    } else {
      buf.write(ch);
    }
  }
  if (buf.isNotEmpty) tokens.add(buf.toString());
  return tokens;
}

/// Resolves [name] to a launchable absolute path so [Process.start] can run it
/// directly (no shell), which keeps the spawned process a direct child we can
/// reliably kill.
///
/// - A name containing a path separator is resolved relative to [workingDir].
/// - A bare name is searched on `PATH`, trying Windows `PATHEXT` extensions
///   (so `dart`/`node`/`python` resolve to `dart.exe` etc.).
/// - If nothing is found, [name] is returned unchanged as a best-effort.
String resolveExecutable(String name, Directory workingDir) {
  if (name.contains('/') || name.contains('\\')) {
    final abs = p.isAbsolute(name) ? name : p.join(workingDir.path, name);
    return File(abs).existsSync() ? abs : name;
  }

  final pathEnv = Platform.environment['PATH'] ??
      Platform.environment['Path'] ??
      '';
  final sep = Platform.isWindows ? ';' : ':';
  final exts = Platform.isWindows
      ? (Platform.environment['PATHEXT']?.split(';') ??
          const ['.EXE', '.BAT', '.CMD', '.COM'])
      : const [''];

  for (final dir in pathEnv.split(sep)) {
    if (dir.isEmpty) continue;
    for (final ext in exts) {
      final candidate = p.join(dir, '$name$ext');
      if (File(candidate).existsSync()) return candidate;
    }
  }
  return name;
}

/// Spawns and supervises a single plugin OS process, restarting it with backoff
/// if it exits unexpectedly. The process is told how to reach the host via
/// command-line args: `--mdk-port`, `--mdk-plugin-id`, `--mdk-token`.
class PluginProcess {
  final String pluginId;
  final String token;
  final int hostPort;
  final String runCommand;
  final Directory workingDir;

  /// Max automatic restarts within [_restartWindow] before giving up.
  static const int _maxRestarts = 5;
  static const Duration _restartWindow = Duration(minutes: 1);

  Process? _process;
  bool _stopped = false;
  final List<DateTime> _restarts = [];

  PluginProcess({
    required this.pluginId,
    required this.token,
    required this.hostPort,
    required this.runCommand,
    required this.workingDir,
  });

  bool get isRunning => _process != null;

  /// Starts the process (and keeps it running until [stop]).
  Future<void> start() async {
    _stopped = false;
    await _spawn();
  }

  Future<void> _spawn() async {
    final parts = parseRunCommand(runCommand);
    if (parts.isEmpty) {
      debugPrint('Plugin "$pluginId" has an empty run command');
      return;
    }
    final executable = resolveExecutable(parts.first, workingDir);
    // `.bat`/`.cmd` shims on Windows can't be launched by CreateProcess
    // directly; run those through a shell. Real executables (.exe) and POSIX
    // binaries are launched directly so they stay a killable direct child.
    final lower = executable.toLowerCase();
    final needsShell = Platform.isWindows &&
        (lower.endsWith('.bat') || lower.endsWith('.cmd'));
    final args = [
      ...parts.skip(1),
      '--mdk-port', '$hostPort',
      '--mdk-plugin-id', pluginId,
      '--mdk-token', token,
    ];

    try {
      final process = await Process.start(
        executable,
        args,
        workingDirectory: workingDir.path,
        runInShell: needsShell,
      );
      _process = process;
      // Surface plugin stdout/stderr in the server log for debugging.
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => debugPrint('[$pluginId] $line'));
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => debugPrint('[$pluginId:err] $line'));
      process.exitCode.then(_onExit);
    } catch (e) {
      debugPrint('Failed to start plugin "$pluginId": $e');
      _process = null;
    }
  }

  void _onExit(int code) {
    _process = null;
    if (_stopped) return;
    debugPrint('Plugin "$pluginId" exited (code $code)');

    // Bounded restart: drop restarts older than the window, then check the cap.
    final now = DateTime.now();
    _restarts.removeWhere((t) => now.difference(t) > _restartWindow);
    if (_restarts.length >= _maxRestarts) {
      debugPrint('Plugin "$pluginId" crashed too often; not restarting');
      return;
    }
    _restarts.add(now);
    final delay = Duration(milliseconds: 500 * (_restarts.length));
    Timer(delay, () {
      if (!_stopped) _spawn();
    });
  }

  /// Stops the process and prevents further restarts.
  Future<void> stop() async {
    _stopped = true;
    final process = _process;
    _process = null;
    if (process != null) {
      process.kill();
    }
  }
}
