import 'package:flutter_test/flutter_test.dart';
import 'package:marco_deck/src/models/button.dart';

void main() {
  Button sampleButton({String name = 'Browser'}) => Button(
        name: name,
        iconName: 'globe',
        actions: [ButtonAction(type: ActionType.command, command: 'echo hi')],
        color: '#3B82F6',
      );

  group('Tile', () {
    test('round-trips with embedded button and spans', () {
      final button = sampleButton();
      final tile = Tile(button: button, colSpan: 2, rowSpan: 2);

      final restored = Tile.fromJson(tile.toJson());

      expect(restored.id, tile.id);
      expect(restored.buttonId, button.id);
      expect(restored.colSpan, 2);
      expect(restored.rowSpan, 2);
      expect(restored.button.name, 'Browser');
      expect(restored.button.actions.first.command, 'echo hi');
    });

    test('defaults to 1x1', () {
      final tile = Tile(button: sampleButton());
      expect(tile.colSpan, 1);
      expect(tile.rowSpan, 1);
    });
  });

  group('Page', () {
    test('round-trips columns and tiles', () {
      final page = Page(
        name: 'Apps',
        order: 2,
        columns: 5,
        tiles: [
          Tile(button: sampleButton(name: 'A'), colSpan: 2),
          Tile(button: sampleButton(name: 'B'), rowSpan: 2),
        ],
      );

      final restored = Page.fromJson(page.toJson());

      expect(restored.name, 'Apps');
      expect(restored.order, 2);
      expect(restored.columns, 5);
      expect(restored.tiles, hasLength(2));
      expect(restored.tiles[0].button.name, 'A');
      expect(restored.tiles[0].colSpan, 2);
      expect(restored.tiles[1].rowSpan, 2);
    });

    test('defaults columns when omitted', () {
      final page = Page(name: 'P', tiles: []);
      expect(page.columns, greaterThan(0));
    });
  });
}
