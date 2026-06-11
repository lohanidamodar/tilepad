import 'package:flutter_test/flutter_test.dart';
import 'package:tilepad/src/server/plugins/plugin_process.dart';

void main() {
  group('parseRunCommand', () {
    test('splits a simple command', () {
      expect(parseRunCommand('node plugin.js'), ['node', 'plugin.js']);
    });

    test('handles a bare executable', () {
      expect(parseRunCommand('./plugin.exe'), ['./plugin.exe']);
    });

    test('keeps quoted segments with spaces together', () {
      expect(
        parseRunCommand('"C:\\My Tools\\node.exe" plugin.js'),
        ['C:\\My Tools\\node.exe', 'plugin.js'],
      );
    });

    test('collapses repeated spaces', () {
      expect(parseRunCommand('dart   plugin.dart'), ['dart', 'plugin.dart']);
    });

    test('returns empty for an empty command', () {
      expect(parseRunCommand('   '), isEmpty);
    });
  });
}
