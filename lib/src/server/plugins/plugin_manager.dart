import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'plugin_host.dart';
import 'plugin_process.dart';
import 'plugin_registry.dart';

/// Everything a launcher needs to start one plugin and have it connect back.
class PluginLaunchSpec {
  final String pluginId;
  final String token;
  final int hostPort;
  final String runCommand;
  final Directory workingDir;

  PluginLaunchSpec({
    required this.pluginId,
    required this.token,
    required this.hostPort,
    required this.runCommand,
    required this.workingDir,
  });
}

/// Starts a plugin process for a launch spec. Overridable for tests.
typedef PluginLauncher = Future<void> Function(PluginLaunchSpec spec);

/// Coordinates the [PluginRegistry] (what exists / is enabled), the
/// [PluginHost] (the connection + protocol) and the OS processes. Enabling a
/// plugin generates a one-time token, allows it on the host, and launches its
/// process; disabling stops the process and disconnects it.
class PluginManager {
  final PluginRegistry registry;
  final PluginHost host;
  final _uuid = const Uuid();

  late final PluginLauncher _launcher;
  final Map<String, PluginProcess> _processes = {};

  PluginManager({
    required this.registry,
    required this.host,
    PluginLauncher? launcher,
  }) {
    _launcher = launcher ?? _defaultLauncher;
  }

  /// The platform key used to resolve a plugin's `run` command.
  static String get currentPlatform {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return Platform.operatingSystem;
  }

  /// Launches every currently-enabled plugin (call once after registry.load()).
  Future<void> startAll() async {
    for (final plugin in registry.plugins) {
      if (plugin.enabled) {
        await _launch(plugin);
      }
    }
  }

  /// Enables and launches a plugin.
  Future<void> enable(String id) async {
    await registry.setEnabled(id, true);
    final plugin = registry.byId(id);
    if (plugin != null) await _launch(plugin);
  }

  /// Disables a plugin: stops its process and disconnects it from the host.
  Future<void> disable(String id) async {
    await registry.setEnabled(id, false);
    await _processes.remove(id)?.stop();
    await host.disconnect(id);
  }

  /// Pushes updated settings to a (possibly running) plugin and persists them.
  Future<void> updateSettings(String id, Map<String, dynamic> settings) async {
    await registry.setSettings(id, settings);
    host.pushSettings(id, settings);
  }

  Future<void> _launch(InstalledPlugin plugin) async {
    final id = plugin.manifest.id;
    var runCommand = plugin.manifest.runCommandFor(currentPlatform);
    if (runCommand == null) {
      debugPrint('Plugin "$id" has no run command for $currentPlatform');
      return;
    }
    runCommand = resolveRunFallback(runCommand, plugin.directory);
    // Stop any process already running for this id so re-enabling (or a stray
    // startAll after enable) can't spawn a duplicate or orphan the old one.
    await _processes.remove(id)?.stop();
    final token = _uuid.v4();
    host.allowPlugin(id, token, settings: plugin.settings);
    await _launcher(PluginLaunchSpec(
      pluginId: id,
      token: token,
      hostPort: host.port,
      runCommand: runCommand,
      workingDir: plugin.directory,
    ));
  }

  /// Release bundles ship plugins as compiled binaries (e.g. `./obs-plugin`),
  /// but a source checkout has only the Dart sources. When the manifest's
  /// command points at a plugin-local binary that doesn't exist, fall back to
  /// running `plugin.dart` with the Dart SDK so dev setups keep working.
  static String resolveRunFallback(String runCommand, Directory workingDir) {
    final parts = parseRunCommand(runCommand);
    if (parts.isEmpty) return runCommand;
    final first = parts.first;
    final isLocalPath = first.contains('/') || first.contains('\\');
    if (!isLocalPath) return runCommand;
    final binary = File(
        p.isAbsolute(first) ? first : p.join(workingDir.path, first));
    if (binary.existsSync()) return runCommand;
    final source = File(p.join(workingDir.path, 'plugin.dart'));
    if (source.existsSync()) {
      debugPrint(
          'Plugin binary $first not found; falling back to "dart plugin.dart"');
      return 'dart plugin.dart';
    }
    return runCommand;
  }

  Future<void> _defaultLauncher(PluginLaunchSpec spec) async {
    final process = PluginProcess(
      pluginId: spec.pluginId,
      token: spec.token,
      hostPort: spec.hostPort,
      runCommand: spec.runCommand,
      workingDir: spec.workingDir,
    );
    _processes[spec.pluginId] = process;
    await process.start();
  }

  /// Stops all plugin processes.
  Future<void> stopAll() async {
    for (final process in _processes.values) {
      await process.stop();
    }
    _processes.clear();
  }
}
