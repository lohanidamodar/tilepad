@Tags(['e2e'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilepad/src/models/button.dart';
import 'package:tilepad/src/models/message.dart';
import 'package:tilepad/src/server/server.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression test: after a server restart, each client message must be
/// handled exactly once. start() used to add a fresh message-stream listener
/// on every start without cancelling the old one, so one restart made every
/// button press execute twice (prompt text typed twice, toggles flipped back).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('mdk_restart_test');
    // Route path_provider to the temp dir so config persistence works.
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tempDir.path,
    );
  });

  tearDown(() async {
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  Future<int> freePort() async {
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();
    return port;
  }

  test('a button press is handled exactly once after a server restart',
      () async {
    final server = TilepadServer(
      port: await freePort(),
      pluginPort: await freePort(),
    );
    addTearDown(server.dispose);

    expect(await server.start(), isTrue);

    // A prompt-text button: pressing it with empty text is an instant no-op
    // success on every platform, so the test counts results, not side effects.
    final button = Button(
      name: 'Type Something',
      iconName: '1',
      actions: [ButtonAction(type: ActionType.promptText)],
    );
    server.addLibraryButton(button);

    // The duplication trigger: a restart re-subscribed without cancelling.
    expect(await server.restart(), isTrue);

    final socket =
        await WebSocket.connect('ws://127.0.0.1:${server.serverPort}');
    addTearDown(() => socket.close());

    final received = <Message>[];
    final ackReceived = Completer<void>();
    socket.listen((data) {
      final message = Message.decode(data as String);
      received.add(message);
      if (message.type == MessageType.connectAck &&
          !ackReceived.isCompleted) {
        ackReceived.complete();
      }
    });

    socket.add(Message(
      type: MessageType.connect,
      payload: {'deviceName': 'Test Device'},
    ).encode());
    await ackReceived.future.timeout(const Duration(seconds: 5));

    socket.add(Message(
      type: MessageType.buttonPress,
      payload: {'buttonId': button.id, 'text': ''},
    ).encode());

    // Give a duplicated handler ample time to produce a second result.
    await Future.delayed(const Duration(seconds: 2));

    final results =
        received.where((m) => m.type == MessageType.commandResult).toList();
    expect(results, hasLength(1),
        reason: 'one press must produce exactly one command result '
            '(duplicates mean start() leaked a message subscription)');

    await server.stop();
  });
}
