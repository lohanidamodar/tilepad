import 'package:flutter_test/flutter_test.dart';
import 'package:marco_deck/src/models/button.dart';
import 'package:marco_deck/src/server/button_presets.dart';

void main() {
  group('button preset catalog', () {
    final catalog = buttonPresetCatalog();

    test('exposes the expected categories', () {
      expect(
        catalog.map((c) => c.name),
        containsAll(<String>[
          'Media',
          'System',
          'Apps',
          'Web',
          'Window',
          'Clipboard',
          'Navigation',
        ]),
      );
    });

    test('every preset is well-formed (name, icon, exactly one action)', () {
      for (final preset in allPresetButtons()) {
        expect(preset.name, isNotEmpty, reason: 'name');
        expect(preset.iconName, isNotEmpty, reason: '${preset.name} icon');
        expect(preset.color, startsWith('#'), reason: '${preset.name} color');
        expect(preset.actions, hasLength(1), reason: '${preset.name} actions');
      }
    });

    test('media presets carry a media key, web presets carry a URL', () {
      final media = catalog.firstWhere((c) => c.name == 'Media');
      for (final b in media.buttons) {
        expect(b.actions.first.type, ActionType.mediaKey);
        expect(b.actions.first.key, isNotEmpty);
      }
      final web = catalog.firstWhere((c) => c.name == 'Web');
      for (final b in web.buttons) {
        expect(b.actions.first.type, ActionType.openUrl);
        expect(b.actions.first.command, startsWith('http'));
      }
    });

    test('navigation presets use navigatePage with a direction', () {
      final nav = catalog.firstWhere((c) => c.name == 'Navigation');
      expect(nav.buttons.map((b) => b.navigationTarget), containsAll(['next', 'prev']));
    });

    test('preset names are unique', () {
      final names = allPresetButtons().map((b) => b.name).toList();
      expect(names.toSet(), hasLength(names.length));
    });
  });
}
