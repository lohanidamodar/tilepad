import 'package:flutter_test/flutter_test.dart';
import 'package:tilepad/src/server/command_executor.dart';

void main() {
  final executor = CommandExecutor();

  group('executeDelay', () {
    test('waits roughly the requested time and succeeds', () async {
      final stopwatch = Stopwatch()..start();
      final result = await executor.executeDelay('120');
      stopwatch.stop();
      expect(result.success, isTrue);
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(100));
    });

    test('rejects non-numeric input', () async {
      final result = await executor.executeDelay('soon');
      expect(result.success, isFalse);
      expect(result.error, contains('soon'));
    });

    test('rejects negative delays', () async {
      final result = await executor.executeDelay('-5');
      expect(result.success, isFalse);
    });

    test('treats zero as a no-op success', () async {
      final result = await executor.executeDelay('0');
      expect(result.success, isTrue);
    });
  });
}
