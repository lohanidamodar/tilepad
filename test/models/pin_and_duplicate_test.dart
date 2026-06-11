import 'package:flutter_test/flutter_test.dart';
import 'package:tilepad/src/models/button.dart';
import 'package:tilepad/src/models/server_connection.dart';

void main() {
  group('ServerConnection pin', () {
    test('round-trips through JSON', () {
      final connection = ServerConnection(
        name: 'Desk PC',
        address: 'ws://192.168.1.10:8080',
        pin: '123456',
      );
      final restored = ServerConnection.fromJson(connection.toJson());
      expect(restored.pin, '123456');
    });

    test('defaults to empty and is omitted from JSON when unset', () {
      final connection =
          ServerConnection(name: 'Desk PC', address: 'ws://x:8080');
      expect(connection.pin, isEmpty);
      expect(connection.toJson().containsKey('pin'), isFalse);
      // Legacy stored JSON without the field still parses.
      final restored = ServerConnection.fromJson(connection.toJson());
      expect(restored.pin, isEmpty);
    });

    test('copyWith sets and preserves the pin', () {
      final connection =
          ServerConnection(name: 'Desk PC', address: 'ws://x:8080');
      final paired = connection.copyWith(pin: '654321');
      expect(paired.pin, '654321');
      expect(paired.copyWith(name: 'Renamed').pin, '654321');
    });
  });

  group('Button.duplicate', () {
    test('deep-copies everything under a fresh id and resets the face', () {
      final original = Button(
        name: 'Mute',
        iconName: '1',
        color: '#112233',
        actions: [ButtonAction(type: ActionType.mediaKey, key: 'mute')],
        toggleState: ToggleState(
          name: 'Unmute',
          actions: [ButtonAction(type: ActionType.mediaKey, key: 'mute')],
        ),
        toggled: true,
        longPressActions: [
          ButtonAction(type: ActionType.command, command: 'hold'),
        ],
      );

      final copy = original.duplicate();

      expect(copy.id, isNot(original.id));
      expect(copy.name, 'Mute copy');
      expect(copy.color, original.color);
      expect(copy.toggled, isFalse);
      expect(copy.toggleState?.name, 'Unmute');
      expect(copy.longPressActions.single.command, 'hold');

      // Mutating the copy's actions must not touch the original.
      copy.actions.first.key = 'volumeUp';
      copy.toggleState!.actions.first.key = 'volumeUp';
      expect(original.actions.first.key, 'mute');
      expect(original.toggleState!.actions.first.key, 'mute');
    });
  });
}
