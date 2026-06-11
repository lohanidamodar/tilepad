// A minimal Tilepad plugin written in Dart, using only the Dart SDK so it
// runs with `dart plugin.dart` and needs no `pub get`.
//
// It demonstrates every plugin capability:
//   - an action with a field (`say_hello`)
//   - a dynamic option list (`colors`)
//   - a configurable plugin setting (`greeting`)
//   - a live state streamed to the client every second (`clock`)
//
// The Tilepad server launches this process with:
//   dart plugin.dart --mdk-port <port> --mdk-plugin-id <id> --mdk-token <token>
// We connect back to ws://127.0.0.1:<port>, register, then speak the protocol.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final opts = _parseArgs(args);
  final port = opts['mdk-port'];
  final pluginId = opts['mdk-plugin-id'];
  final token = opts['mdk-token'];
  if (port == null || pluginId == null || token == null) {
    stderr.writeln('Missing --mdk-port/--mdk-plugin-id/--mdk-token');
    exit(1);
  }

  final plugin = HelloPlugin(
    port: int.parse(port),
    pluginId: pluginId,
    token: token,
  );
  await plugin.run();
}

Map<String, String> _parseArgs(List<String> args) {
  final out = <String, String>{};
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i].startsWith('--')) {
      out[args[i].substring(2)] = args[i + 1];
    }
  }
  return out;
}

class HelloPlugin {
  final int port;
  final String pluginId;
  final String token;

  WebSocket? _socket;
  Timer? _clock;
  String _greeting = 'Hello';

  HelloPlugin({
    required this.port,
    required this.pluginId,
    required this.token,
  });

  Future<void> run() async {
    // If the host vanishes while we're starting up, don't hang as a zombie —
    // a plugin should exit when it can't reach (or loses) the host.
    final WebSocket socket;
    try {
      socket = await WebSocket.connect('ws://127.0.0.1:$port')
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      stderr.writeln('Could not connect to host: $e');
      exit(1);
    }
    _socket = socket;

    // 1) Register with the host.
    _send({'type': 'register', 'pluginId': pluginId, 'token': token});

    socket.listen(
      (data) => _onMessage(data as String),
      onDone: _shutdown,
      onError: (_) => _shutdown(),
    );
  }

  void _onMessage(String data) {
    final msg = jsonDecode(data) as Map<String, dynamic>;
    switch (msg['type'] as String?) {
      case 'registered':
        // The host hands over the current settings on registration.
        final settings = msg['settings'] as Map<String, dynamic>? ?? {};
        _greeting = (settings['greeting'] as String?) ?? 'Hello';
        _startClock();
        break;

      case 'settingsUpdated':
        final settings = msg['settings'] as Map<String, dynamic>? ?? {};
        _greeting = (settings['greeting'] as String?) ?? _greeting;
        break;

      case 'invoke':
        _handleInvoke(msg);
        break;

      case 'requestList':
        _handleRequestList(msg);
        break;

      case 'shutdown':
        _shutdown();
        break;
    }
  }

  void _handleInvoke(Map<String, dynamic> msg) {
    final requestId = msg['requestId'];
    final actionId = msg['actionId'] as String?;
    final fields = msg['fields'] as Map<String, dynamic>? ?? {};

    switch (actionId) {
      case 'say_hello':
        final name = (fields['name'] as String?) ?? 'World';
        _send({
          'type': 'actionResult',
          'requestId': requestId,
          'success': true,
          'output': '$_greeting, $name!',
        });
        break;

      case 'pick_color':
        final color = (fields['color'] as String?) ?? '(none)';
        _send({
          'type': 'actionResult',
          'requestId': requestId,
          'success': true,
          'output': 'You picked $color',
        });
        break;

      default:
        _send({
          'type': 'actionResult',
          'requestId': requestId,
          'success': false,
          'error': 'Unknown action: $actionId',
        });
    }
  }

  void _handleRequestList(Map<String, dynamic> msg) {
    final requestId = msg['requestId'];
    final listId = msg['listId'] as String?;
    if (listId == 'colors') {
      _send({
        'type': 'listResult',
        'requestId': requestId,
        'options': [
          {'value': 'red', 'label': 'Red'},
          {'value': 'green', 'label': 'Green'},
          {'value': 'blue', 'label': 'Blue'},
        ],
      });
    } else {
      _send({'type': 'listResult', 'requestId': requestId, 'options': []});
    }
  }

  /// Streams the current time to a live `clock` state once per second.
  void _startClock() {
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      final hh = now.hour.toString().padLeft(2, '0');
      final mm = now.minute.toString().padLeft(2, '0');
      final ss = now.second.toString().padLeft(2, '0');
      _send({'type': 'setState', 'stateId': 'clock', 'value': '$hh:$mm:$ss'});
    });
  }

  void _send(Map<String, dynamic> msg) => _socket?.add(jsonEncode(msg));

  void _shutdown() {
    _clock?.cancel();
    _socket?.close();
    exit(0);
  }
}
