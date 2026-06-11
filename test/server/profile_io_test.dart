import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:marco_deck/src/models/button.dart';
import 'package:marco_deck/src/server/button_manager.dart';

void main() {
  // saveConfig() inside importProfile touches path_provider, which isn't
  // available in unit tests; ButtonManager swallows that error and the
  // in-memory state (what these tests assert on) is unaffected.
  TestWidgetsFlutterBinding.ensureInitialized();

  ButtonManager seeded() {
    final manager = ButtonManager();
    final button = Button(
      name: 'Browser',
      iconName: '1',
      actions: [ButtonAction(type: ActionType.command, command: 'firefox')],
    );
    manager.addLibraryButton(button);
    manager.addPage(Page(name: 'Main', columns: 4));
    manager.addTile(manager.pages.first.id, button.id, colSpan: 2);
    return manager;
  }

  group('exportProfile', () {
    test('exports buttons and normalised pages with a version marker', () {
      final manager = seeded();
      final data = jsonDecode(manager.exportProfile()) as Map<String, dynamic>;

      expect(data['marcoDeckProfile'], 1);
      expect(data['buttons'], hasLength(1));
      expect(data['pages'], hasLength(1));
      final tile = (data['pages'][0]['tiles'] as List).single;
      expect(tile['buttonId'], manager.buttons.first.id);
      expect(tile['colSpan'], 2);
      // Normalised storage: tiles carry a reference, not the whole button.
      expect(tile.containsKey('button'), isFalse);
    });
  });

  group('importProfile', () {
    test('round-trips an exported profile', () async {
      final source = seeded();
      final exported = source.exportProfile();

      final target = ButtonManager();
      final error = await target.importProfile(exported);

      expect(error, isNull);
      expect(target.buttons, hasLength(1));
      expect(target.buttons.first.name, 'Browser');
      expect(target.pages, hasLength(1));
      expect(target.pages.first.tiles, hasLength(1));
      expect(target.pages.first.tiles.first.colSpan, 2);
      expect(target.pages.first.tiles.first.button.name, 'Browser');
    });

    test('replaces the existing configuration', () async {
      final manager = seeded();
      final exported = manager.exportProfile();

      // Mutate, then import the old snapshot back.
      manager.addLibraryButton(Button(
        name: 'Extra',
        iconName: '2',
        actions: [ButtonAction(type: ActionType.command, command: 'x')],
      ));
      expect(manager.buttons, hasLength(2));

      final error = await manager.importProfile(exported);
      expect(error, isNull);
      expect(manager.buttons, hasLength(1));
    });

    test('rejects malformed JSON and keeps the current config', () async {
      final manager = seeded();
      final error = await manager.importProfile('not json at all');
      expect(error, isNotNull);
      expect(manager.buttons, hasLength(1));
      expect(manager.pages, hasLength(1));
    });

    test('rejects a profile without buttons', () async {
      final manager = seeded();
      final error = await manager.importProfile('{"pages": []}');
      expect(error, isNotNull);
      expect(manager.buttons, hasLength(1));
    });

    test('drops tiles whose button is missing from the profile', () async {
      final manager = ButtonManager();
      final error = await manager.importProfile(jsonEncode({
        'buttons': [
          Button(
            name: 'Known',
            iconName: '1',
            actions: [ButtonAction(type: ActionType.command, command: 'a')],
          ).toJson(),
        ],
        'pages': [
          {
            'id': 'p1',
            'name': 'Main',
            'order': 0,
            'columns': 4,
            'tiles': [
              {'id': 't1', 'buttonId': 'does-not-exist'},
            ],
          },
        ],
      }));
      expect(error, isNull);
      expect(manager.pages.single.tiles, isEmpty);
    });
  });
}
