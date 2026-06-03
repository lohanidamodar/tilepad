import 'package:flutter_test/flutter_test.dart';
import 'package:marco_deck/src/models/button.dart';

void main() {
  group('new action types', () {
    test('openUrl round-trips through JSON with its target in command', () {
      final action =
          ButtonAction(type: ActionType.openUrl, command: 'https://youtube.com');
      final restored = ButtonAction.fromJson(action.toJson());
      expect(restored.type, ActionType.openUrl);
      expect(restored.command, 'https://youtube.com');
    });

    test('mediaKey round-trips with its key name', () {
      final action = ButtonAction(type: ActionType.mediaKey, key: 'playPause');
      final restored = ButtonAction.fromJson(action.toJson());
      expect(restored.type, ActionType.mediaKey);
      expect(restored.key, 'playPause');
    });

    test('navigatePage round-trips with its target in command', () {
      final action =
          ButtonAction(type: ActionType.navigatePage, command: 'next');
      final restored = ButtonAction.fromJson(action.toJson());
      expect(restored.type, ActionType.navigatePage);
      expect(restored.command, 'next');
    });
  });

  group('navigation buttons', () {
    Button nav(String target) => Button(
          name: 'Nav',
          iconName: 'arrow',
          actions: [ButtonAction(type: ActionType.navigatePage, command: target)],
        );

    test('navigationTarget returns the target for a navigate button', () {
      expect(nav('next').navigationTarget, 'next');
      expect(nav('prev').navigationTarget, 'prev');
    });

    test('navigationTarget is null for a non-navigation button', () {
      final b = Button(
        name: 'Cmd',
        iconName: 'x',
        actions: [ButtonAction(type: ActionType.command, command: 'echo hi')],
      );
      expect(b.navigationTarget, isNull);
    });

    test('a navigation button is not treated as a prompt', () {
      expect(nav('next').isPrompt, isFalse);
    });
  });
}
