import 'package:flutter_test/flutter_test.dart';
import 'package:marco_deck/src/models/button.dart';
import 'package:marco_deck/src/server/button_manager.dart';

void main() {
  late ButtonManager mgr;

  Button btn(String name) => Button(
        name: name,
        iconName: 'star',
        actions: [ButtonAction(type: ActionType.command, command: 'echo')],
      );

  setUp(() {
    mgr = ButtonManager();
  });

  test('library add + lookup', () {
    final b = btn('A');
    mgr.addLibraryButton(b);
    expect(mgr.buttons, hasLength(1));
    expect(mgr.getButton(b.id)!.name, 'A');
  });

  test('addTile places a library button on a page (resolved)', () {
    final b = btn('A');
    mgr.addLibraryButton(b);
    final page = Page(name: 'P', columns: 4);
    mgr.addPage(page);

    final tile = mgr.addTile(page.id, b.id, colSpan: 2, rowSpan: 2);

    expect(tile, isNotNull);
    expect(mgr.getPage(page.id)!.tiles, hasLength(1));
    expect(mgr.getPage(page.id)!.tiles.first.button.name, 'A');
    expect(tile!.colSpan, 2);
  });

  test('addTile fails for unknown button or page', () {
    expect(mgr.addTile('nope', 'nope'), isNull);
  });

  test('deleting a library button purges its tiles from every page', () {
    final b = btn('A');
    mgr.addLibraryButton(b);
    final p1 = Page(name: 'P1');
    final p2 = Page(name: 'P2');
    mgr.addPage(p1);
    mgr.addPage(p2);
    mgr.addTile(p1.id, b.id);
    mgr.addTile(p2.id, b.id);

    mgr.deleteButton(b.id);

    expect(mgr.getButton(b.id), isNull);
    expect(mgr.getPage(p1.id)!.tiles, isEmpty);
    expect(mgr.getPage(p2.id)!.tiles, isEmpty);
  });

  test('updateButton is reflected in placed tiles', () {
    final b = btn('A');
    mgr.addLibraryButton(b);
    final page = Page(name: 'P');
    mgr.addPage(page);
    mgr.addTile(page.id, b.id);

    mgr.updateButton(Button(id: b.id, name: 'Renamed', iconName: 'star'));

    expect(mgr.getPage(page.id)!.tiles.first.button.name, 'Renamed');
  });

  test('resize and reorder tiles', () {
    final a = btn('A');
    final c = btn('C');
    mgr.addLibraryButton(a);
    mgr.addLibraryButton(c);
    final page = Page(name: 'P', columns: 4);
    mgr.addPage(page);
    final t1 = mgr.addTile(page.id, a.id)!;
    mgr.addTile(page.id, c.id);

    expect(mgr.resizeTile(page.id, t1.id, 3, 2), isTrue);
    expect(mgr.getPage(page.id)!.tiles.first.colSpan, 3);

    mgr.reorderTiles(page.id, 0, 1);
    expect(mgr.getPage(page.id)!.tiles.first.button.name, 'C');
  });

  test('removeTile drops a placement but keeps the library button', () {
    final b = btn('A');
    mgr.addLibraryButton(b);
    final page = Page(name: 'P');
    mgr.addPage(page);
    final t = mgr.addTile(page.id, b.id)!;

    expect(mgr.removeTile(page.id, t.id), isTrue);
    expect(mgr.getPage(page.id)!.tiles, isEmpty);
    expect(mgr.getButton(b.id), isNotNull);
  });
}
