import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marco_deck/src/server/plugins/plugin_host.dart';
import 'package:marco_deck/src/server/plugins/plugin_manager.dart';
import 'package:marco_deck/src/server/plugins/plugin_protocol.dart';
import 'package:marco_deck/src/server/plugins/plugin_registry.dart';
import 'package:path/path.dart' as p;
import 'package:web_socket_channel/io.dart';

/// Launcher that connects an in-process fake plugin instead of spawning an OS
/// process, using the token the manager generated.
class _FakeLauncher {
  final List<IOWebSocketChannel> channels = [];

  Future<void> call(PluginLaunchSpec spec) async {
    final channel =
        IOWebSocketChannel.connect(Uri.parse('ws://127.0.0.1:${spec.hostPort}'));
    await channel.ready;
    channels.add(channel);
    channel.sink.add(jsonEncode({
      'type': PluginProtocol.register,
      'pluginId': spec.pluginId,
      'token': spec.token,
    }));
  }

  Future<void> closeAll() async {
    for (final c in channels) {
      await c.sink.close();
    }
  }
}

void main() {
  late Directory tmp;
  late PluginHost host;
  late PluginRegistry registry;
  late _FakeLauncher launcher;
  late PluginManager manager;

  void writePlugin(String id) {
    final dir = Directory(p.join(tmp.path, id))..createSync(recursive: true);
    File(p.join(dir.path, 'manifest.json')).writeAsStringSync(jsonEncode({
      'id': id,
      'name': id,
      'version': '1.0.0',
      'author': 'Me',
      'run': {'windows': 'x', 'macos': 'x', 'linux': 'x'},
    }));
  }

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('mdk_manager_test');
    host = PluginHost(requestTimeout: const Duration(seconds: 2));
    await host.start(port: 0);
    registry = PluginRegistry(tmp);
    launcher = _FakeLauncher();
    manager = PluginManager(
      registry: registry,
      host: host,
      launcher: launcher.call,
    );
  });

  tearDown(() async {
    await launcher.closeAll();
    await host.stop();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<bool> waitConnected(String id) async {
    for (var i = 0; i < 50; i++) {
      if (host.isConnected(id)) return true;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return false;
  }

  test('enable launches the plugin and it registers with the host', () async {
    writePlugin('com.a');
    await registry.load();

    await manager.enable('com.a');

    expect(registry.byId('com.a')!.enabled, isTrue);
    expect(await waitConnected('com.a'), isTrue);
  });

  test('startAll launches only enabled plugins', () async {
    writePlugin('com.a');
    writePlugin('com.b');
    await registry.load();
    await registry.setEnabled('com.a', true);

    await manager.startAll();

    expect(await waitConnected('com.a'), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(host.isConnected('com.b'), isFalse);
  });

  test('disable disconnects the plugin', () async {
    writePlugin('com.a');
    await registry.load();
    await manager.enable('com.a');
    expect(await waitConnected('com.a'), isTrue);

    await manager.disable('com.a');

    expect(registry.byId('com.a')!.enabled, isFalse);
    expect(host.isConnected('com.a'), isFalse);
  });
}
