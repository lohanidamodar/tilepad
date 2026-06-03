@Tags(['e2e'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marco_deck/src/server/plugins/plugin_host.dart';
import 'package:marco_deck/src/server/plugins/plugin_manager.dart';
import 'package:marco_deck/src/server/plugins/plugin_registry.dart';
import 'package:path/path.dart' as p;

/// Spawns the real OBS plugin process and drives it through the host protocol.
/// OBS itself is NOT required: with no OBS reachable the plugin must still
/// register and report its connection state as Disconnected. (Live OBS control
/// is verified manually against a running OBS.) Requires `dart` on PATH.
void main() {
  const id = 'com.marcodeck.obs';
  late Directory tmp;
  late PluginHost host;
  late PluginRegistry registry;
  late PluginManager manager;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('mdk_obs_e2e');
    final src = Directory(
        p.join(Directory.current.path, 'assets', 'plugins', 'obs'));
    final dst = Directory(p.join(tmp.path, 'obs'))..createSync(recursive: true);
    for (final name in ['manifest.json', 'plugin.dart', 'obs_protocol.dart']) {
      File(p.join(src.path, name)).copySync(p.join(dst.path, name));
    }
    // Exercise the Dart source directly (the shipped manifest launches a
    // pre-compiled native binary, which this test doesn't build). Rewrite the
    // run command in the copied manifest to interpret the source on every OS.
    final manifestFile = File(p.join(dst.path, 'manifest.json'));
    final json = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
    json['run'] = {
      'windows': 'dart plugin.dart',
      'macos': 'dart plugin.dart',
      'linux': 'dart plugin.dart',
    };
    await manifestFile.writeAsString(jsonEncode(json));

    host = PluginHost(requestTimeout: const Duration(seconds: 8));
    await host.start(port: 0);
    registry = PluginRegistry(tmp);
    await registry.load();
    manager = PluginManager(registry: registry, host: host);
  });

  tearDown(() async {
    await manager.stopAll();
    await host.stop();
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
      if (host.isConnected(id)) return true;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return false;
  }

  test('OBS plugin registers and reports Disconnected without OBS running',
      () async {
    // Point at a port nothing is listening on so the OBS connect fails fast.
    await manager.enable(id);
    expect(await waitConnected(), isTrue,
        reason: 'plugin did not connect to host (is `dart` on PATH?)');

    await manager.updateSettings(id, {'host': '127.0.0.1', 'port': 1});

    // The plugin should publish its connection state as Disconnected.
    var disconnected = false;
    for (var i = 0; i < 60; i++) {
      final s = host.stateStore.get(id, 'obs');
      if (s?.value == 'Disconnected') {
        disconnected = true;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(disconnected, isTrue, reason: 'expected obs=Disconnected state');

    // Actions fail cleanly while OBS is unreachable.
    final result = await host.invoke(id, 'toggle_record', const {});
    expect(result.success, isFalse);
    expect(result.error, contains('OBS'));

    await manager.disable(id);
    expect(host.isConnected(id), isFalse);
  });
}
