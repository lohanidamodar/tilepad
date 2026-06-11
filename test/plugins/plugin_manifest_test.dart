import 'package:flutter_test/flutter_test.dart';
import 'package:tilepad/src/server/plugins/plugin_manifest.dart';

void main() {
  Map<String, dynamic> validJson() => {
        'id': 'com.you.obs',
        'name': 'OBS Control',
        'version': '1.0.0',
        'author': 'You',
        'apiVersion': 1,
        'run': {
          'windows': 'node plugin.js',
          'macos': 'node plugin.js',
          'linux': 'node plugin.js',
        },
        'settings': [
          {'key': 'host', 'type': 'string', 'label': 'OBS host', 'default': 'localhost'},
          {'key': 'password', 'type': 'password', 'label': 'Password'},
        ],
        'actions': [
          {
            'id': 'switch_scene',
            'name': 'Switch Scene',
            'icon': 'icon.png',
            'fields': [
              {'key': 'scene', 'type': 'select', 'label': 'Scene', 'optionsFrom': 'scenes'},
            ],
          },
          {'id': 'toggle_mute', 'name': 'Toggle Mic Mute'},
        ],
        'states': [
          {'id': 'current_scene', 'label': 'Current Scene', 'type': 'string'},
          {'id': 'mic_muted', 'label': 'Mic Muted', 'type': 'bool'},
        ],
        'lists': [
          {'id': 'scenes', 'label': 'Scenes'},
        ],
      };

  group('PluginManifest.fromJson', () {
    test('parses identity fields', () {
      final m = PluginManifest.fromJson(validJson());
      expect(m.id, 'com.you.obs');
      expect(m.name, 'OBS Control');
      expect(m.version, '1.0.0');
      expect(m.author, 'You');
      expect(m.apiVersion, 1);
    });

    test('parses run commands and resolves per platform', () {
      final m = PluginManifest.fromJson(validJson());
      expect(m.runCommandFor('windows'), 'node plugin.js');
      expect(m.runCommandFor('linux'), 'node plugin.js');
      expect(m.runCommandFor('fuchsia'), isNull);
    });

    test('parses settings fields', () {
      final m = PluginManifest.fromJson(validJson());
      expect(m.settings, hasLength(2));
      final host = m.settings.first;
      expect(host.key, 'host');
      expect(host.type, PluginFieldType.string);
      expect(host.label, 'OBS host');
      expect(host.defaultValue, 'localhost');
      expect(m.settings[1].type, PluginFieldType.password);
    });

    test('parses actions with fields', () {
      final m = PluginManifest.fromJson(validJson());
      expect(m.actions, hasLength(2));
      final switchScene = m.actions.first;
      expect(switchScene.id, 'switch_scene');
      expect(switchScene.name, 'Switch Scene');
      expect(switchScene.icon, 'icon.png');
      expect(switchScene.fields, hasLength(1));
      final field = switchScene.fields.first;
      expect(field.type, PluginFieldType.select);
      expect(field.optionsFrom, 'scenes');
      // action with no fields parses to empty list
      expect(m.actions[1].fields, isEmpty);
    });

    test('parses states and lists', () {
      final m = PluginManifest.fromJson(validJson());
      expect(m.states.map((s) => s.id), ['current_scene', 'mic_muted']);
      expect(m.states[1].type, 'bool');
      expect(m.lists.single.id, 'scenes');
    });

    test('defaults apiVersion to 1 when missing', () {
      final json = validJson()..remove('apiVersion');
      expect(PluginManifest.fromJson(json).apiVersion, 1);
    });

    test('ignores unknown keys for forward compatibility', () {
      final json = validJson()..['somethingNew'] = 'ignored';
      expect(() => PluginManifest.fromJson(json), returnsNormally);
    });

    test('throws when required id is missing', () {
      final json = validJson()..remove('id');
      expect(
        () => PluginManifest.fromJson(json),
        throwsA(isA<PluginManifestException>()),
      );
    });

    test('throws when run is missing', () {
      final json = validJson()..remove('run');
      expect(
        () => PluginManifest.fromJson(json),
        throwsA(isA<PluginManifestException>()),
      );
    });

    test('throws on unknown field type', () {
      final json = validJson();
      (json['settings'] as List).add({'key': 'x', 'type': 'wat', 'label': 'X'});
      expect(
        () => PluginManifest.fromJson(json),
        throwsA(isA<PluginManifestException>()),
      );
    });

    test('rejects an apiVersion newer than the host supports', () {
      final json = validJson()
        ..['apiVersion'] = PluginManifest.supportedApiVersion + 1;
      expect(
        () => PluginManifest.fromJson(json),
        throwsA(isA<PluginManifestException>()),
      );
    });

    test('accepts the current apiVersion', () {
      final json = validJson()..['apiVersion'] = PluginManifest.supportedApiVersion;
      expect(PluginManifest.fromJson(json).apiVersion,
          PluginManifest.supportedApiVersion);
    });
  });
}
