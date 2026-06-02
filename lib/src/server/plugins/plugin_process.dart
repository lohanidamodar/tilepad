import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

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
    final executable = parts.first;
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
