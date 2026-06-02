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
        if (byId(manifest.id) != null) {
          _errors.add(
            '${p.basename(entry.path)}: duplicate plugin id "${manifest.id}" '
            '(already loaded) — skipped',
          );
          continue;
        }
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
    // Write to a temp file then rename so a crash mid-write can't corrupt the
    // existing state.
    final tmp = File('${_stateFile.path}.tmp');
    await tmp.writeAsString(jsonEncode(state), flush: true);
    await tmp.rename(_stateFile.path);
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

    // The manifest's folder ('' for a root manifest, else e.g. 'pluginX') is the
    // root we re-base every entry under.
    final prefixDir = p.dirname(manifestEntry.name);
    final prefix =
        (prefixDir == '.' || prefixDir.isEmpty) ? '' : '$prefixDir/';

    final target = Directory(p.join(pluginsDir.path, manifest.id));
    final targetPath = p.normalize(target.path);

    // Plan the extraction first; reject the whole archive (zip-slip) before
    // writing anything if any entry would escape the plugin directory.
    final planned = <String, List<int>>{};
    for (final file in archive.files) {
      if (!file.isFile) continue;
      // Only take entries inside the manifest's folder.
      if (prefix.isNotEmpty && !file.name.startsWith(prefix)) continue;
      final rel = prefix.isEmpty ? file.name : file.name.substring(prefix.length);
      final outPath = p.normalize(p.join(target.path, rel));
      if (!p.isWithin(targetPath, outPath)) {
        throw PluginInstallException(
          'Archive entry "${file.name}" escapes the plugin directory',
        );
      }
      planned[outPath] = file.content as List<int>;
    }

    if (await target.exists()) {
      await target.delete(recursive: true);
    }
    await target.create(recursive: true);
    for (final entry in planned.entries) {
      final outFile = File(entry.key);
      await outFile.parent.create(recursive: true);
      await outFile.writeAsBytes(entry.value);
    }

    final installed = InstalledPlugin(manifest: manifest, directory: target);
    _plugins.removeWhere((e) => e.manifest.id == manifest.id);
    _plugins.add(installed);
    await _writeState();
    return installed;
  }

  /// Installs a plugin by copying a source folder into the plugins directory.
  ///
  /// The folder must contain a valid `manifest.json` at its root. The copy is
  /// placed at `<pluginsDir>/<plugin.id>/` so removal stays self-contained.
  Future<InstalledPlugin> installFromDirectory(Directory source) async {
    final manifestFile = File(p.join(source.path, 'manifest.json'));
    if (!await manifestFile.exists()) {
      throw PluginInstallException('Folder has no manifest.json');
    }

    final PluginManifest manifest;
    try {
      manifest = PluginManifest.fromJson(
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>);
    } catch (e) {
      throw PluginInstallException('Invalid manifest in folder: $e');
    }

    final target = Directory(p.join(pluginsDir.path, manifest.id));
    // Avoid copying a folder into itself (already installed in place).
    if (p.equals(source.path, target.path)) {
      final existing = InstalledPlugin(manifest: manifest, directory: target);
      _plugins.removeWhere((e) => e.manifest.id == manifest.id);
      _plugins.add(existing);
      await _writeState();
      return existing;
    }
    if (await target.exists()) {
      await target.delete(recursive: true);
    }
    await _copyDirectory(source, target);

    final installed = InstalledPlugin(manifest: manifest, directory: target);
    _plugins.removeWhere((e) => e.manifest.id == manifest.id);
    _plugins.add(installed);
    await _writeState();
    return installed;
  }

  /// Recursively copies [source] into [destination].
  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      final newPath = p.join(destination.path, p.basename(entity.path));
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      } else if (entity is File) {
        await entity.copy(newPath);
      }
    }
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
