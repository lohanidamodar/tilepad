import 'package:flutter_test/flutter_test.dart';
import 'package:tilepad/src/models/button.dart';

void main() {
  group('ButtonAction plugin type', () {
    test('round-trips a plugin action through JSON', () {
      final action = ButtonAction(
        type: ActionType.plugin,
        pluginId: 'com.you.obs',
        pluginActionId: 'switch_scene',
        settings: {'scene': 'Intro'},
      );
      final restored = ButtonAction.fromJson(action.toJson());
      expect(restored.type, ActionType.plugin);
      expect(restored.pluginId, 'com.you.obs');
      expect(restored.pluginActionId, 'switch_scene');
      expect(restored.settings, {'scene': 'Intro'});
    });

    test('legacy command action without plugin fields still parses', () {
      final json = {
        'id': 'x',
        'type': 'command',
        'command': 'echo hi',
        'key': '',
        'modifiers': <String>[],
      };
      final action = ButtonAction.fromJson(json);
      expect(action.type, ActionType.command);
      expect(action.pluginId, '');
      expect(action.settings, isEmpty);
    });
  });

  group('Button state binding', () {
    test('round-trips a state binding', () {
      final button = Button(
        name: 'Scene',
        iconName: 'tv',
        actions: [
          ButtonAction(
            type: ActionType.plugin,
            pluginId: 'com.you.obs',
            pluginActionId: 'switch_scene',
          ),
        ],
        stateBinding: StateBinding(
          pluginId: 'com.you.obs',
          stateId: 'current_scene',
          mode: StateBindingMode.title,
        ),
      );
      final restored = Button.fromJson(button.toJson());
      expect(restored.stateBinding, isNotNull);
      expect(restored.stateBinding!.pluginId, 'com.you.obs');
      expect(restored.stateBinding!.stateId, 'current_scene');
      expect(restored.stateBinding!.mode, StateBindingMode.title);
    });

    test('button without a binding deserializes with null binding', () {
      final button = Button(name: 'Plain', iconName: 'star', actions: [
        ButtonAction(type: ActionType.command, command: 'echo'),
      ]);
      final restored = Button.fromJson(button.toJson());
      expect(restored.stateBinding, isNull);
    });

    test('legacy button JSON (no stateBinding key) still parses', () {
      final json = {
        'id': 'b1',
        'name': 'Old',
        'iconName': 'star',
        'actions': [
          {'id': 'a', 'type': 'command', 'command': 'echo', 'key': '', 'modifiers': []},
        ],
        'color': '#4285F4',
      };
      final button = Button.fromJson(json);
      expect(button.stateBinding, isNull);
      expect(button.name, 'Old');
    });
  });
}
