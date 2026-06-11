import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tilepad/src/server/plugins/plugin_host.dart';
import 'package:tilepad/src/server/plugins/plugin_protocol.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A minimal in-process plugin used to drive the host over a real WebSocket.
class FakePlugin {
  final WebSocketChannel channel;
  final _incoming = StreamController<Map<String, dynamic>>.broadcast();

  FakePlugin._(this.channel) {
    channel.stream.listen((data) {
      _incoming.add(jsonDecode(data as String) as Map<String, dynamic>);
    });
  }

  static Future<FakePlugin> connect(int port) async {
    final channel =
        IOWebSocketChannel.connect(Uri.parse('ws://127.0.0.1:$port'));
    await channel.ready;
    return FakePlugin._(channel);
  }

  Stream<Map<String, dynamic>> get incoming => _incoming.stream;

  void send(Map<String, dynamic> msg) => channel.sink.add(jsonEncode(msg));

  /// Waits for the next message of [type].
  Future<Map<String, dynamic>> waitFor(String type) =>
      incoming.firstWhere((m) => m['type'] == type);

  Future<void> close() async {
    await channel.sink.close();
    await _incoming.close();
  }
}

void main() {
  late PluginHost host;

  setUp(() async {
    host = PluginHost(requestTimeout: const Duration(seconds: 2));
    await host.start(port: 0); // ephemeral port
  });

  tearDown(() async {
    await host.stop();
  });

  Future<FakePlugin> registerPlugin(
    String id,
    String token, {
    Map<String, dynamic> settings = const {},
  }) async {
    host.allowPlugin(id, token, settings: settings);
    final plugin = await FakePlugin.connect(host.port);
    plugin.send({'type': PluginProtocol.register, 'pluginId': id, 'token': token});
    await plugin.waitFor(PluginProtocol.registered);
    return plugin;
  }

  test('accepts a plugin that registers with a valid token', () async {
    final plugin = await registerPlugin('com.a', 'secret');
    expect(host.isConnected('com.a'), isTrue);
    await plugin.close();
  });

  test('registered message hands over current settings', () async {
    host.allowPlugin('com.a', 'secret', settings: {'host': 'h.example'});
    final plugin = await FakePlugin.connect(host.port);
    plugin.send({'type': PluginProtocol.register, 'pluginId': 'com.a', 'token': 'secret'});
    final registered = await plugin.waitFor(PluginProtocol.registered);
    expect(registered['settings'], {'host': 'h.example'});
    await plugin.close();
  });

  test('rejects a plugin with an invalid token', () async {
    host.allowPlugin('com.a', 'secret');
    final plugin = await FakePlugin.connect(host.port);
    plugin.send({'type': PluginProtocol.register, 'pluginId': 'com.a', 'token': 'wrong'});
    // The host should not mark it connected.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(host.isConnected('com.a'), isFalse);
    await plugin.close();
  });

  test('invoke sends to plugin and returns its actionResult', () async {
    final plugin = await registerPlugin('com.a', 'secret');
    plugin.incoming.listen((msg) {
      if (msg['type'] == PluginProtocol.invoke) {
        plugin.send({
          'type': PluginProtocol.actionResult,
          'requestId': msg['requestId'],
          'success': true,
          'output': 'did ${msg['actionId']}',
        });
      }
    });

    final result = await host.invoke('com.a', 'toggle', {'x': 1});
    expect(result.success, isTrue);
    expect(result.output, 'did toggle');
    await plugin.close();
  });

  test('invoke on a disconnected plugin returns a failure result', () async {
    final result = await host.invoke('com.missing', 'toggle', {});
    expect(result.success, isFalse);
    expect(result.error, contains('not connected'));
  });

  test('invoke times out when the plugin never replies', () async {
    final plugin = await registerPlugin('com.a', 'secret');
    // plugin ignores invoke
    final result = await host.invoke('com.a', 'toggle', {});
    expect(result.success, isFalse);
    expect(result.error.toLowerCase(), contains('time'));
    await plugin.close();
  });

  test('requestList returns the options the plugin supplies', () async {
    final plugin = await registerPlugin('com.a', 'secret');
    plugin.incoming.listen((msg) {
      if (msg['type'] == PluginProtocol.requestList) {
        plugin.send({
          'type': PluginProtocol.listResult,
          'requestId': msg['requestId'],
          'options': [
            {'value': 's1', 'label': 'Scene 1'},
            {'value': 's2', 'label': 'Scene 2'},
          ],
        });
      }
    });

    final options = await host.requestList('com.a', 'scenes');
    expect(options.map((o) => o.value), ['s1', 's2']);
    expect(options.first.label, 'Scene 1');
    await plugin.close();
  });

  test('setState updates the state store', () async {
    final plugin = await registerPlugin('com.a', 'secret');
    plugin.send({
      'type': PluginProtocol.setState,
      'stateId': 'scene',
      'value': 'Live',
    });
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(host.stateStore.get('com.a', 'scene')!.value, 'Live');
    await plugin.close();
  });

  test('setStateImage updates the state store image', () async {
    final plugin = await registerPlugin('com.a', 'secret');
    plugin.send({
      'type': PluginProtocol.setStateImage,
      'stateId': 'mic',
      'image': 'muted.png',
    });
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(host.stateStore.get('com.a', 'mic')!.image, 'muted.png');
    await plugin.close();
  });

  test('disconnect marks the plugin not connected and clears its state',
      () async {
    final plugin = await registerPlugin('com.a', 'secret');
    plugin.send({
      'type': PluginProtocol.setState,
      'stateId': 'scene',
      'value': 'Live',
    });
    await Future<void>.delayed(const Duration(milliseconds: 100));

    await host.disconnect('com.a');
    expect(host.isConnected('com.a'), isFalse);
    expect(host.stateStore.get('com.a', 'scene'), isNull);
    await plugin.close();
  });

  test('in-flight invoke fails fast when the plugin disconnects', () async {
    final plugin = await registerPlugin('com.a', 'secret');
    // plugin never replies to invoke
    final future = host.invoke('com.a', 'toggle', {});
    // Disconnect while the request is in flight.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await host.disconnect('com.a');

    final result = await future.timeout(const Duration(seconds: 1));
    expect(result.success, isFalse);
    await plugin.close();
  });

  test('pushSettings forwards settingsUpdated to the plugin', () async {
    final plugin = await registerPlugin('com.a', 'secret');
    final future = plugin.waitFor(PluginProtocol.settingsUpdated);
    host.pushSettings('com.a', {'host': 'new.example'});
    final msg = await future;
    expect(msg['settings'], {'host': 'new.example'});
    await plugin.close();
  });
}
