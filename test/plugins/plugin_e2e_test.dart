@Tags(['e2e'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tilepad/src/server/plugins/plugin_host.dart';
import 'package:tilepad/src/server/plugins/plugin_manager.dart';
import 'package:tilepad/src/server/plugins/plugin_registry.dart';
import 'package:path/path.dart' as p;

/// End-to-end test that spawns the real `hello_dart` demo plugin as an actual OS
/// process (via the default launcher) and drives the full protocol. This is the
/// "device" validation of process spawning + the wire protocol that the unit
/// tests stub out. Requires the Dart SDK on PATH.
void main() {
  late Directory tmp;
  late PluginHost host;
  late PluginRegistry registry;
  late PluginManager manager;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('mdk_e2e');
    // Copy the demo plugin into a temp plugins dir.
    final src = Directory(p.join(Directory.current.path, 'examples', 'plugins',
        'hello_dart'));
    final dst = Directory(p.join(tmp.path, 'hello_dart'))
      ..createSync(recursive: true);
    for (final name in ['manifest.json', 'plugin.dart']) {
      File(p.join(src.path, name)).copySync(p.join(dst.path, name));
    }

    host = PluginHost(requestTimeout: const Duration(seconds: 8));
    await host.start(port: 0);
    registry = PluginRegistry(tmp);
    await registry.load();
    manager = PluginManager(registry: registry, host: host);
  });

  tearDown(() async {
    await manager.stopAll();
    await host.stop();
    // The killed process may briefly keep its working dir locked on Windows;
    // retry deletion a few times before giving up.
    for (var i = 0; i < 20 && tmp.existsSync(); i++) {
      try {
        tmp.deleteSync(recursive: true);
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  });

  Future<bool> waitConnected() async {
    for (var i = 0; i < 150; i++) {
      if (host.isConnected('com.tilepad.hello_dart')) return true;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return false;
  }

  test('demo plugin connects, invokes, lists, streams state and reconfigures',
      () async {
    await manager.enable('com.tilepad.hello_dart');
    expect(await waitConnected(), isTrue,
        reason: 'plugin process did not connect (is `dart` on PATH?)');

    // Action invocation with a field.
    final hello = await host.invoke(
        'com.tilepad.hello_dart', 'say_hello', {'name': 'Damodar'});
    expect(hello.success, isTrue);
    expect(hello.output, 'Hello, Damodar!');

    // Dynamic option list.
    final colors = await host.requestList('com.tilepad.hello_dart', 'colors');
    expect(colors.map((o) => o.value), ['red', 'green', 'blue']);

    // Live state streamed by the plugin's clock (every second).
    var clockSeen = false;
    for (var i = 0; i < 30; i++) {
      if (host.stateStore.get('com.tilepad.hello_dart', 'clock') != null) {
        clockSeen = true;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(clockSeen, isTrue, reason: 'no clock state received');

    // Settings push changes behaviour.
    await manager.updateSettings(
        'com.tilepad.hello_dart', {'greeting': 'Hi'});
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final hi = await host.invoke(
        'com.tilepad.hello_dart', 'say_hello', {'name': 'World'});
    expect(hi.output, 'Hi, World!');

    // Disable stops the process and disconnects.
    await manager.disable('com.tilepad.hello_dart');
    expect(host.isConnected('com.tilepad.hello_dart'), isFalse);
  });
}
