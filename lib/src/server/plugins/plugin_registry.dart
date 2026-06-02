import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'plugin_manifest.dart';

/// Thrown when installing a plugin (e.g. from a zip) fails.
class PluginInstallException implements Exception {
  final String message;
  PluginInstallException(this.message);
  @override
  String toString() => 'PluginInstallException: $message';
}

/// An installed plugin: its parsed manifest, on-disk location, and the
/// user-controlled enabled flag and settings values.
class InstalledPlugin {
  final PluginManifest manifest;
  final Directory directory;
  bool enabled;
  Map<String, dynamic> settings;

  InstalledPlugin({
    required this.manifest,
    required this.directory,
    this.enabled = false,
    Map<String, dynamic>? settings,
  }) : settings = settings ?? <String, dynamic>{};
}

/// Discovers plugins on disk, tracks their enabled/settings state (persisted to
/// a `registry.json` alongside the plugin folders), and installs/removes them.
///
/// The registry does not start processes — that is [PluginHost]'s job. It is the
/// source of truth for *what* plugins exist and *whether* they should run.
class PluginRegistry {
  /// Directory containing one sub-folder per plugin.
  final Directory pluginsDir;

  final List<InstalledPlugin> _plugins = [];
  final List<String> _errors = [];

  PluginRegistry(this.pluginsDir);

  List<InstalledPlugin> get plugins => List.unmodifiable(_plugins);

  /// Discovery/parse errors collected during [load], for surfacing in the UI.
  List<String> get errors => List.unmodifiable(_errors);

  InstalledPlugin? byId(String id) {
    for (final plugin in _plugins) {
      if (plugin.manifest.id == id) return plugin;
    }
    return null;
  }

  File get _stateFile => File(p.join(pluginsDir.path, 'registry.json'));

  /// Scans [pluginsDir] for plugin folders and loads persisted state.
  Future<void> load() async {
    _plugins.clear();
    _errors.clear();

    if (!await pluginsDir.exists()) {
      await pluginsDir.create(recursive: true);
      return;
    }

    final state = await _readState();

    await for (final entry in pluginsDir.list()) {
      if (entry is! Directory) continue;
      final manifestFile = File(p.join(entry.path, 'manifest.json'));
      if (!await manifestFile.exists()) continue;

      try {
        final json =
            jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
        final manifest = PluginManifest.fromJson(json);
        final saved = state[manifest.id] as Map<String, dynamic>?;
        _plugins.add(
          InstalledPlugin(
            manifest: manifest,
            directory: entry,
            enabled: saved?['enabled'] as bool? ?? false,
            settings: (saved?['settings'] as Map<String, dynamic>?) ?? {},
          ),
        );
      } catch (e) {
        _errors.add('${p.basename(entry.path)}: $e');
      }
    }
  }

  Future<Map<String, dynamic>> _readState() async {
    try {
      if (await _stateFile.exists()) {
        return jsonDecode(await _stateFile.readAsString())
            as Map<String, dynamic>;
      }
    } catch (_) {
      // Corrupt state file — start fresh rather than fail discovery.
    }
    return {};
  }

  Future<void> _writeState() async {
    final state = <String, dynamic>{};
    for (final plugin in _plugins) {
      state[plugin.manifest.id] = {
        'enabled': plugin.enabled,
        'settings': plugin.settings,
      };
    }
    await _stateFile.writeAsString(jsonEncode(state));
  }

  /// Enables or disables a plugin and persists the change.
  Future<void> setEnabled(String id, bool enabled) async {
    final plugin = byId(id);
    if (plugin == null) return;
    plugin.enabled = enabled;
    await _writeState();
  }

  /// Replaces a plugin's settings values and persists them.
  Future<void> setSettings(String id, Map<String, dynamic> values) async {
    final plugin = byId(id);
    if (plugin == null) return;
    plugin.settings = Map<String, dynamic>.from(values);
    await _writeState();
  }

  /// Installs a plugin from a `.zip`. The archive must contain a `manifest.json`
  /// (at the root or one level deep). Returns the newly installed plugin.
  Future<InstalledPlugin> installFromZip(File zipFile) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());
    } catch (e) {
      throw PluginInstallException('Could not read zip: $e');
    }

    // Locate the manifest to determine the root prefix inside the archive.
    final manifestEntry = archive.files.firstWhere(
      (f) => f.isFile && p.basename(f.name) == 'manifest.json',
      orElse: () => throw PluginInstallException('No manifest.json in archive'),
    );

    final PluginManifest manifest;
    try {
      final content = utf8.decode(manifestEntry.content as List<int>);
      manifest = PluginManifest.fromJson(
          jsonDecode(content) as Map<String, dynamic>);
    } catch (e) {
      throw PluginInstallException('Invalid manifest in archive: $e');
    }

    final prefix = p.dirname(manifestEntry.name); // '' or 'pluginX'
    final target = Directory(p.join(pluginsDir.path, manifest.id));
    if (await target.exists()) {
      await target.delete(recursive: true);
    }
    await target.create(recursive: true);

    for (final file in archive.files) {
      if (!file.isFile) continue;
      // Re-root entries under the manifest's folder.
      var rel = file.name;
      if (prefix != '.' && prefix.isNotEmpty) {
        if (!p.isWithin(prefix, file.name) && p.dirname(file.name) != prefix) {
          // File outside the plugin folder — skip.
          if (!file.name.startsWith('$prefix/')) continue;
        }
        rel = p.relative(file.name, from: prefix);
      }
      final outPath = p.join(target.path, rel);
      // Guard against zip-slip path traversal.
      if (!p.isWithin(target.path, outPath) &&
          p.normalize(outPath) != p.normalize(target.path)) {
        continue;
      }
      final outFile = File(outPath);
      await outFile.parent.create(recursive: true);
      await outFile.writeAsBytes(file.content as List<int>);
    }

    final installed = InstalledPlugin(manifest: manifest, directory: target);
    _plugins.removeWhere((e) => e.manifest.id == manifest.id);
    _plugins.add(installed);
    await _writeState();
    return installed;
  }

  /// Removes a plugin and deletes its directory.
  Future<void> remove(String id) async {
    final plugin = byId(id);
    if (plugin == null) return;
    if (await plugin.directory.exists()) {
      await plugin.directory.delete(recursive: true);
    }
    _plugins.removeWhere((e) => e.manifest.id == id);
    await _writeState();
  }
}
