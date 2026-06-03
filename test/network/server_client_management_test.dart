@Tags(['e2e'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marco_deck/src/network/websocket_service.dart';
import 'package:web_socket_channel/io.dart';

/// Exercises the server-side client management (disconnect + IP blocklist)
/// against a real loopback WebSocket, the way the server runs in production.
void main() {
  late ServerWebSocketService server;
  late int port;

  setUp(() async {
    // Grab a free ephemeral port, then hand it to the server.
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    port = probe.port;
    await probe.close();

    server = ServerWebSocketService();
    expect(await server.start(port), isTrue);
  });

  tearDown(() async {
    await server.close();
  });

  test('disconnectClient closes the client socket', () async {
    // Subscribe before connecting so we never miss the connect event.
    final connectEvent =
        server.clientConnectionStream.firstWhere((e) => e.connected);
    final channel = IOWebSocketChannel.connect('ws://127.0.0.1:$port');
    await channel.ready;

    final client = (await connectEvent.timeout(const Duration(seconds: 5)))
        .clientInfo;
    expect(client.ipAddress, '127.0.0.1');

    final disconnectEvent =
        server.clientConnectionStream.firstWhere((e) => !e.connected);

    server.disconnectClient(client.id);

    // Wait for the server to process the close (removes from connectedClients).
    await disconnectEvent.timeout(const Duration(seconds: 5));
    expect(server.connectedClients, isEmpty);
  });

  test('blocking an IP kicks the client and rejects reconnection', () async {
    final connectEvent =
        server.clientConnectionStream.firstWhere((e) => e.connected);
    final channel = IOWebSocketChannel.connect('ws://127.0.0.1:$port');
    await channel.ready;
    await connectEvent.timeout(const Duration(seconds: 5));

    final closed = Completer<void>();
    channel.stream.listen((_) {},
        onDone: () => closed.complete(), onError: (_) {});

    server.updateBlockedIps({'127.0.0.1'});

    // Existing client is dropped.
    await closed.future.timeout(const Duration(seconds: 5));

    // A fresh connection from the blocked IP is refused at the upgrade.
    final blocked = IOWebSocketChannel.connect('ws://127.0.0.1:$port');
    await expectLater(
      blocked.ready.timeout(const Duration(seconds: 5)),
      throwsA(anything),
    );
  });

  test('unblocking via empty set lets the IP connect again', () async {
    server.updateBlockedIps({'127.0.0.1'});
    final blocked = IOWebSocketChannel.connect('ws://127.0.0.1:$port');
    await expectLater(
      blocked.ready.timeout(const Duration(seconds: 5)),
      throwsA(anything),
    );

    // Clear the blocklist; the same IP should now upgrade successfully.
    server.updateBlockedIps({});
    final connectEvent =
        server.clientConnectionStream.firstWhere((e) => e.connected);
    final channel = IOWebSocketChannel.connect('ws://127.0.0.1:$port');
    await channel.ready;
    await connectEvent.timeout(const Duration(seconds: 5));
    expect(server.connectedClients, isNotEmpty);
  });
}
