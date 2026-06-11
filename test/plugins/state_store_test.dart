import 'package:flutter_test/flutter_test.dart';
import 'package:tilepad/src/server/plugins/state_store.dart';

void main() {
  group('StateStore', () {
    test('stores and retrieves a value', () {
      final store = StateStore();
      store.set('com.a', 'scene', value: 'Intro');
      final entry = store.get('com.a', 'scene');
      expect(entry, isNotNull);
      expect(entry!.value, 'Intro');
      expect(entry.pluginId, 'com.a');
      expect(entry.stateId, 'scene');
    });

    test('overwrites an existing value', () {
      final store = StateStore();
      store.set('com.a', 'scene', value: 'Intro');
      store.set('com.a', 'scene', value: 'Live');
      expect(store.get('com.a', 'scene')!.value, 'Live');
    });

    test('stores an image alongside value', () {
      final store = StateStore();
      store.set('com.a', 'mic', value: 'muted', image: 'mute.png');
      expect(store.get('com.a', 'mic')!.image, 'mute.png');
    });

    test('snapshot returns all current entries', () {
      final store = StateStore();
      store.set('com.a', 'scene', value: 'Intro');
      store.set('com.b', 'temp', value: '64');
      expect(store.snapshot().map((e) => e.stateId).toSet(), {'scene', 'temp'});
    });

    test('emits changes on the stream', () async {
      final store = StateStore();
      final events = <StateEntry>[];
      final sub = store.changes.listen(events.add);
      store.set('com.a', 'scene', value: 'Intro');
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));
      expect(events.single.value, 'Intro');
      await sub.cancel();
    });

    test('does not re-emit unchanged values (sampled states)', () async {
      final store = StateStore();
      final events = <StateEntry>[];
      final sub = store.changes.listen(events.add);
      store.set('system', 'window', value: 'Editor');
      store.set('system', 'window', value: 'Editor'); // same → no event
      store.set('system', 'window', value: 'Browser'); // change → event
      store.set('system', 'window', value: 'Browser', image: 'b.png');
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(3));
      expect(events.map((e) => e.value), ['Editor', 'Browser', 'Browser']);
      await sub.cancel();
    });

    test('clearPlugin removes that plugin\'s entries only', () {
      final store = StateStore();
      store.set('com.a', 'scene', value: 'Intro');
      store.set('com.b', 'temp', value: '64');
      store.clearPlugin('com.a');
      expect(store.get('com.a', 'scene'), isNull);
      expect(store.get('com.b', 'temp'), isNotNull);
    });
  });
}
