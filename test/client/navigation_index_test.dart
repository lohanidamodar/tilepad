import 'package:flutter_test/flutter_test.dart';
import 'package:marco_deck/src/client/button_grid.dart';

void main() {
  group('resolveNavigationIndex', () {
    test('next advances and wraps at the end', () {
      expect(resolveNavigationIndex('next', 0, 3), 1);
      expect(resolveNavigationIndex('next', 2, 3), 0);
    });

    test('prev goes back and wraps at the start', () {
      expect(resolveNavigationIndex('prev', 2, 3), 1);
      expect(resolveNavigationIndex('prev', 0, 3), 2);
      expect(resolveNavigationIndex('previous', 0, 3), 2);
    });

    test('first and last jump to the ends', () {
      expect(resolveNavigationIndex('first', 2, 3), 0);
      expect(resolveNavigationIndex('last', 0, 3), 2);
    });

    test('absolute index is clamped', () {
      expect(resolveNavigationIndex('index:1', 0, 3), 1);
      expect(resolveNavigationIndex('index:9', 0, 3), 2);
      expect(resolveNavigationIndex('2', 0, 3), 2);
    });

    test('unknown target or empty page set keeps the current index', () {
      expect(resolveNavigationIndex('bogus', 1, 3), 1);
      expect(resolveNavigationIndex('next', 0, 0), 0);
    });
  });
}
