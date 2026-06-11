import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilepad/src/client/client_providers.dart';

void main() {
  group('PluginStatesNotifier', () {
    test('keyFor composes a stable key', () {
      expect(PluginStatesNotifier.keyFor('com.a', 'scene'), 'com.a|scene');
    });

    test('update stores the latest value', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(pluginStatesProvider.notifier)
          .update('com.a', 'scene', value: 'Intro');

      final states = container.read(pluginStatesProvider);
      expect(states['com.a|scene']!.displayText, 'Intro');
    });

    test('update overwrites the previous value', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(pluginStatesProvider.notifier);

      notifier.update('com.a', 'scene', value: 'Intro');
      notifier.update('com.a', 'scene', value: 'Live');

      expect(container.read(pluginStatesProvider)['com.a|scene']!.value, 'Live');
    });

    test('stores image for icon tiles', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(pluginStatesProvider.notifier)
          .update('com.a', 'mic', value: 'muted', image: 'mic_off');

      expect(
        container.read(pluginStatesProvider)['com.a|mic']!.image,
        'mic_off',
      );
    });
  });
}
