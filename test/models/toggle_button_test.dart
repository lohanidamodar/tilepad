import 'package:flutter_test/flutter_test.dart';
import 'package:tilepad/src/models/button.dart';

void main() {
  group('toggle buttons', () {
    Button toggleButton({bool toggled = false}) => Button(
          name: 'Mute',
          iconName: '100',
          color: '#FF0000',
          actions: [ButtonAction(type: ActionType.mediaKey, key: 'mute')],
          toggleState: ToggleState(
            name: 'Unmute',
            iconName: '200',
            color: '#00FF00',
            actions: [ButtonAction(type: ActionType.mediaKey, key: 'mute')],
          ),
          toggled: toggled,
        );

    test('round-trips toggle face and state through JSON', () {
      final restored = Button.fromJson(toggleButton(toggled: true).toJson());
      expect(restored.toggleState, isNotNull);
      expect(restored.toggled, isTrue);
      expect(restored.toggleState!.name, 'Unmute');
      expect(restored.toggleState!.iconName, '200');
      expect(restored.toggleState!.color, '#00FF00');
      expect(restored.toggleState!.actions, hasLength(1));
      expect(restored.toggleState!.actions.first.key, 'mute');
    });

    test('non-toggle buttons omit toggle fields from JSON', () {
      final json = Button(
        name: 'Plain',
        iconName: '1',
        actions: [ButtonAction(type: ActionType.command, command: 'ls')],
      ).toJson();
      expect(json.containsKey('toggleState'), isFalse);
      expect(json.containsKey('toggled'), isFalse);
    });

    test('effective appearance follows the active face', () {
      final off = toggleButton();
      expect(off.effectiveName, 'Mute');
      expect(off.effectiveIconName, '100');
      expect(off.effectiveColor, '#FF0000');

      final on = toggleButton(toggled: true);
      expect(on.effectiveName, 'Unmute');
      expect(on.effectiveIconName, '200');
      expect(on.effectiveColor, '#00FF00');
    });

    test('empty overrides fall back to the primary face', () {
      final button = Button(
        name: 'Start',
        iconName: '1',
        color: '#112233',
        actions: [ButtonAction(type: ActionType.command, command: 'start')],
        toggleState: ToggleState(name: 'Stop'),
        toggled: true,
      );
      expect(button.effectiveName, 'Stop');
      expect(button.effectiveIconName, '1');
      expect(button.effectiveColor, '#112233');
      // No separate actions on the second face: both faces run the primary
      // action set.
      expect(button.effectiveActions.single.command, 'start');
    });

    test('effectiveActions runs the active face actions', () {
      final button = toggleButton(toggled: true);
      expect(button.effectiveActions, same(button.toggleState!.actions));
      button.toggled = false;
      expect(button.effectiveActions, same(button.actions));
    });
  });

  group('long-press actions', () {
    test('round-trip through JSON', () {
      final button = Button(
        name: 'Scene',
        iconName: '1',
        actions: [ButtonAction(type: ActionType.command, command: 'a')],
        longPressActions: [
          ButtonAction(type: ActionType.command, command: 'b'),
          ButtonAction(type: ActionType.delay, command: '250'),
        ],
      );
      final restored = Button.fromJson(button.toJson());
      expect(restored.longPressActions, hasLength(2));
      expect(restored.longPressActions[0].command, 'b');
      expect(restored.longPressActions[1].type, ActionType.delay);
      expect(restored.longPressActions[1].command, '250');
    });

    test('buttons without long-press actions omit the field from JSON', () {
      final json = Button(
        name: 'Plain',
        iconName: '1',
        actions: [ButtonAction(type: ActionType.command, command: 'ls')],
      ).toJson();
      expect(json.containsKey('longPressActions'), isFalse);
    });
  });

  group('legacy button JSON', () {
    test('keeps toggle and long-press fields in the single-action format', () {
      final button = Button.fromJson({
        'id': 'b1',
        'name': 'Mute',
        'iconName': '1',
        'type': 'command',
        'command': 'mute',
        'toggleState': {'name': 'Unmute'},
        'toggled': true,
        'longPressActions': [
          {'type': 'command', 'command': 'hold'},
        ],
      });
      expect(button.toggleState?.name, 'Unmute');
      expect(button.toggled, isTrue);
      expect(button.longPressActions.single.command, 'hold');
    });
  });

  group('delay actions', () {
    test('round-trips with milliseconds in command', () {
      final action = ButtonAction(type: ActionType.delay, command: '1500');
      final restored = ButtonAction.fromJson(action.toJson());
      expect(restored.type, ActionType.delay);
      expect(restored.command, '1500');
    });
  });
}
