import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marco_deck/src/server/plugins/plugin_registry.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('mdk_registry_test');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Map<String, dynamic> manifest(String id, {String name = 'Demo'}) => {
        'id': id,
        'name': name,
        'version': '1.0.0',
        'author': 'Me',
        'run': {'windows': 'x', 'macos': 'x', 'linux': 'x'},
      };

  /// Writes a plugin folder with a manifest into [dir].
  void writePlugin(Directory dir, String folder, Map<String, dynamic> m) {
    final pdir = Directory(p.join(dir.path, folder))..createSync(recursive: true);
    File(p.join(pdir.path, 'manifest.json')).writeAsStringSync(jsonEncode(m));
  }

  group('PluginRegistry discovery', () {
    test('finds plugins with a valid manifest', () async {
      writePlugin(tmp, 'a', manifest('com.a', name: 'Alpha'));
      writePlugin(tmp, 'b', manifest('com.b', name: 'Beta'));

      final registry = PluginRegistry(tmp);
      await registry.load();

      expect(registry.plugins.map((e) => e.manifest.id).toSet(),
          {'com.a', 'com.b'});
      expect(registry.byId('com.a')!.manifest.name, 'Alpha');
    });

    test('skips folders without a manifest', () async {
      Directory(p.join(tmp.path, 'empty')).createSync();
      writePlugin(tmp, 'good', manifest('com.good'));

      final registry = PluginRegistry(tmp);
      await registry.load();

      expect(registry.plugins, hasLength(1));
      expect(registry.plugins.single.manifest.id, 'com.good');
    });

    test('records an error for an invalid manifest without crashing', () async {
      final bad = Directory(p.join(tmp.path, 'bad'))..createSync();
      File(p.join(bad.path, 'manifest.json')).writeAsStringSync('{not json');
      writePlugin(tmp, 'good', manifest('com.good'));

      final registry = PluginRegistry(tmp);
      await registry.load();

      expect(registry.plugins.map((e) => e.manifest.id), ['com.good']);
      expect(registry.errors, isNotEmpty);
    });

    test('plugins are disabled by default', () async {
      writePlugin(tmp, 'a', manifest('com.a'));
      final registry = PluginRegistry(tmp);
      await registry.load();
      expect(registry.byId('com.a')!.enabled, isFalse);
    });
  });

  group('PluginRegistry enable/settings persistence', () {
    test('enabled state persists across reload', () async {
      writePlugin(tmp, 'a', manifest('com.a'));
      final r1 = PluginRegistry(tmp);
      await r1.load();
      await r1.setEnabled('com.a', true);

      final r2 = PluginRegistry(tmp);
      await r2.load();
      expect(r2.byId('com.a')!.enabled, isTrue);
    });

    test('settings values persist across reload', () async {
      writePlugin(tmp, 'a', manifest('com.a'));
      final r1 = PluginRegistry(tmp);
      await r1.load();
      await r1.setSettings('com.a', {'host': 'example.com'});

      final r2 = PluginRegistry(tmp);
      await r2.load();
      expect(r2.byId('com.a')!.settings['host'], 'example.com');
    });
  });

  group('PluginRegistry installFromDirectory', () {
    test('copies a plugin folder into the plugins dir', () async {
      // A source folder outside the plugins dir.
      final srcRoot = Directory.systemTemp.createTempSync('mdk_src');
      addTearDown(() => srcRoot.deleteSync(recursive: true));
      final src = Directory(p.join(srcRoot.path, 'my_plugin'))
        ..createSync(recursive: true);
      File(p.join(src.path, 'manifest.json'))
          .writeAsStringSync(jsonEncode(manifest('com.dir', name: 'Dir')));
      File(p.join(src.path, 'plugin.dart')).writeAsStringSync('// code');

      final registry = PluginRegistry(tmp);
      await registry.load();
      final installed = await registry.installFromDirectory(src);

      expect(installed.manifest.id, 'com.dir');
      expect(registry.byId('com.dir'), isNotNull);
      // Copied (not referenced) into the managed plugins dir.
      expect(p.isWithin(tmp.path, installed.directory.path), isTrue);
      expect(
        File(p.join(installed.directory.path, 'plugin.dart')).existsSync(),
        isTrue,
      );
      // Newly installed plugins are disabled until enabled.
      expect(installed.enabled, isFalse);
    });

    test('rejects a folder without a manifest', () async {
      final srcRoot = Directory.systemTemp.createTempSync('mdk_src2');
      addTearDown(() => srcRoot.deleteSync(recursive: true));
      final src = Directory(p.join(srcRoot.path, 'no_manifest'))
        ..createSync(recursive: true);
      File(p.join(src.path, 'readme.txt')).writeAsStringSync('hi');

      final registry = PluginRegistry(tmp);
      await registry.load();
      expect(
        () => registry.installFromDirectory(src),
        throwsA(isA<PluginInstallException>()),
      );
    });
  });

  group('PluginRegistry install/remove', () {
    test('installs a plugin from a zip archive', () async {
      // Build a zip containing pluginX/manifest.json
      final archive = Archive();
      final bytes =
          utf8.encode(jsonEncode(manifest('com.zip', name: 'Zipped')));
      archive.addFile(ArchiveFile('pluginX/manifest.json', bytes.length, bytes));
      final zipBytes = ZipEncoder().encode(archive);
      final zipFile = File(p.join(tmp.path, 'plugin.zip'))
        ..writeAsBytesSync(zipBytes);

      final registry = PluginRegistry(tmp);
      await registry.load();
      final installed = await registry.installFromZip(zipFile);

      expect(installed.manifest.id, 'com.zip');
      expect(registry.byId('com.zip'), isNotNull);
      expect(
        File(p.join(installed.directory.path, 'manifest.json')).existsSync(),
        isTrue,
      );
    });

    test('rejects a zip without a manifest', () async {
      final archive = Archive();
      final bytes = utf8.encode('hello');
      archive.addFile(ArchiveFile('readme.txt', bytes.length, bytes));
      final zipBytes = ZipEncoder().encode(archive);
      final zipFile = File(p.join(tmp.path, 'bad.zip'))
        ..writeAsBytesSync(zipBytes);

      final registry = PluginRegistry(tmp);
      await registry.load();
      expect(
        () => registry.installFromZip(zipFile),
        throwsA(isA<PluginInstallException>()),
      );
    });

    test('remove deletes the plugin and its directory', () async {
      writePlugin(tmp, 'a', manifest('com.a'));
      final registry = PluginRegistry(tmp);
      await registry.load();
      final dir = registry.byId('com.a')!.directory;

      await registry.remove('com.a');

      expect(registry.byId('com.a'), isNull);
      expect(dir.existsSync(), isFalse);
    });
  });
}
