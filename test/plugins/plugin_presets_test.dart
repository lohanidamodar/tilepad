import 'package:flutter_test/flutter_test.dart';
import 'package:tilepad/src/models/button.dart';
import 'package:tilepad/src/server/button_presets.dart';
import 'package:tilepad/src/server/plugins/plugin_manifest.dart';

void main() {
  group('PluginPresetDef parsing', () {
    test('parses action and state presets', () {
      final action = PluginPresetDef.fromJson(
          {'name': 'Toggle Rec', 'actionId': 'toggle_record', 'color': '#DC2626'});
      expect(action.name, 'Toggle Rec');
      expect(action.actionId, 'toggle_record');
      expect(action.stateId, isNull);

      final state =
          PluginPresetDef.fromJson({'name': 'Scene', 'stateId': 'scene'});
      expect(state.stateId, 'scene');
      expect(state.actionId, isNull);
    });

    test('rejects a preset with neither actionId nor stateId', () {
      expect(
        () => PluginPresetDef.fromJson({'name': 'Bad'}),
        throwsA(isA<PluginManifestException>()),
      );
    });

    test('manifest exposes its presets', () {
      final manifest = PluginManifest.fromJson({
        'id': 'com.x.y',
        'run': {'linux': 'dart plugin.dart'},
        'actions': [
          {'id': 'toggle_record', 'name': 'Toggle'}
        ],
        'states': [
          {'id': 'scene', 'label': 'Scene'}
        ],
        'presets': [
          {'name': 'Toggle Recording', 'actionId': 'toggle_record'},
          {'name': 'Scene', 'stateId': 'scene'},
        ],
      });
      expect(manifest.presets, hasLength(2));
    });
  });

  group('pluginPresetButton conversion', () {
    test('action preset becomes a plugin-action button', () {
      final b = pluginPresetButton(
          'com.x.y', PluginPresetDef(name: 'Toggle', actionId: 'toggle_record'));
      expect(b.name, 'Toggle');
      expect(b.actions.single.type, ActionType.plugin);
      expect(b.actions.single.pluginId, 'com.x.y');
      expect(b.actions.single.pluginActionId, 'toggle_record');
      expect(b.stateBinding, isNull);
    });

    test('state preset becomes a live tile bound to the state', () {
      final b = pluginPresetButton(
          'com.x.y', PluginPresetDef(name: 'Scene', stateId: 'scene'));
      expect(b.actions, isEmpty);
      expect(b.stateBinding?.pluginId, 'com.x.y');
      expect(b.stateBinding?.stateId, 'scene');
    });

    test('honours explicit color/icon and falls back otherwise', () {
      final custom = pluginPresetButton('p',
          PluginPresetDef(name: 'A', actionId: 'a', color: '#123456', icon: '99'));
      expect(custom.color, '#123456');
      expect(custom.iconName, '99');

      final fallback =
          pluginPresetButton('p', PluginPresetDef(name: 'B', actionId: 'b'));
      expect(fallback.color, isNotEmpty);
      expect(fallback.iconName, isNotEmpty);
    });
  });
}
