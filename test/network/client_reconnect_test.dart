@Tags(['e2e'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marco_deck/src/network/websocket_service_io.dart';

/// Exercises the client service's reconnect behaviour against a real loopback
/// WebSocket server:
///  * a server restart must be survived automatically (regression test — the
///    deliberate-close fix once cleared the remembered address inside
///    connect(), silently disabling ALL auto-reconnect), and
///  * a deliberate close() must NOT reconnect (PIN rejection / disconnect).
void main() {
  HttpServer? server;
  var accepted = 0;
  final sockets = <WebSocket>[];

  Future<HttpServer> startServer(int port) async {
    final s = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    s.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      accepted++;
      sockets.add(socket);
      socket.listen((_) {});
    });
    return s;
  }

  /// Stops the server like a real restart would: upgraded WebSockets are
  /// detached from the HttpServer, so close them explicitly too.
  Future<void> stopServer() async {
    for (final socket in sockets) {
      try {
        await socket.close();
      } catch (_) {}
    }
    sockets.clear();
    await server?.close(force: true);
    server = null;
  }

  Future<void> waitFor(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!condition() && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  setUp(() {
    accepted = 0;
  });

  tearDown(stopServer);

  test('client auto-reconnects after the server restarts', () async {
    server = await startServer(0);
    final port = server!.port;

    final service = IOClientWebSocketService();
    addTearDown(service.close);
    expect(await service.connect('ws://127.0.0.1:$port'), isTrue);
    expect(service.isConnected, isTrue);
    expect(accepted, 1);

    // Restart the server on the same port.
    await stopServer();
    await waitFor(() => !service.isConnected,
        timeout: const Duration(seconds: 5));
    expect(service.isConnected, isFalse,
        reason: 'service should notice the server going away');
    server = await startServer(port);

    // The service must come back on its own (base delay 1s, backoff 1.5x).
    await waitFor(() => service.isConnected);
    expect(service.isConnected, isTrue,
        reason: 'service should auto-reconnect after a server restart');
    expect(accepted, greaterThanOrEqualTo(2));
  });

  test('a deliberate close() stays closed (no auto-reconnect)', () async {
    server = await startServer(0);
    final port = server!.port;

    final service = IOClientWebSocketService();
    expect(await service.connect('ws://127.0.0.1:$port'), isTrue);
    expect(accepted, 1);

    await service.close();

    // Give any (buggy) reconnect loop time to act, then verify silence.
    await Future.delayed(const Duration(seconds: 3));
    expect(service.isConnected, isFalse);
    expect(accepted, 1,
        reason: 'no new connection may arrive after a deliberate close');
  });
}
