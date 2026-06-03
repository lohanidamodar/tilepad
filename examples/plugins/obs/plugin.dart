// MarcoDeck ↔ OBS Studio plugin.
//
// Bridges the MarcoDeck plugin host and OBS Studio's built-in WebSocket server
// (obs-websocket v5). Lets buttons switch scenes and toggle recording/streaming,
// and streams the current scene + record/stream status as live tiles.
//
// Uses only the Dart SDK (`dart:io` WebSocket) plus the sibling
// `obs_protocol.dart` — no `pub get` required. Launched by the host as:
//   dart plugin.dart --mdk-port <port> --mdk-plugin-id <id> --mdk-token <token>
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'obs_protocol.dart';

void main(List<String> args) async {
  final opts = _parseArgs(args);
  final port = opts['mdk-port'];
  final pluginId = opts['mdk-plugin-id'];
  final token = opts['mdk-token'];
  if (port == null || pluginId == null || token == null) {
    stderr.writeln('Missing --mdk-port/--mdk-plugin-id/--mdk-token');
    exit(1);
  }
  await ObsPlugin(
    port: int.parse(port),
    pluginId: pluginId,
    token: token,
  ).run();
}

Map<String, String> _parseArgs(List<String> args) {
  final out = <String, String>{};
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i].startsWith('--')) out[args[i].substring(2)] = args[i + 1];
  }
  return out;
}

class ObsPlugin {
  final int port;
  final String pluginId;
  final String token;

  WebSocket? _host;
  WebSocket? _obs;
  Timer? _obsReconnect;

  // OBS connection settings.
  String _obsHost = '127.0.0.1';
  int _obsPort = 4455;
  String _obsPassword = '';

  // Correlates OBS requestIds with the callback that handles their response.
  final Map<String, void Function(bool ok, Map<String, dynamic> data)>
      _pending = {};
  int _reqCounter = 0;

  ObsPlugin({required this.port, required this.pluginId, required this.token});

  Future<void> run() async {
    final WebSocket socket;
    try {
      socket = await WebSocket.connect('ws://127.0.0.1:$port')
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      stderr.writeln('Could not connect to host: $e');
      exit(1);
    }
    _host = socket;
    _sendHost({'type': 'register', 'pluginId': pluginId, 'token': token});
    socket.listen(
      (data) => _onHostMessage(data as String),
      onDone: _shutdown,
      onError: (_) => _shutdown(),
    );
  }

  // --- Host side -----------------------------------------------------------

  void _onHostMessage(String data) {
    final msg = jsonDecode(data) as Map<String, dynamic>;
    switch (msg['type'] as String?) {
      case 'registered':
        _applySettings(msg['settings'] as Map<String, dynamic>? ?? {});
        _connectObs();
        break;
      case 'settingsUpdated':
        _applySettings(msg['settings'] as Map<String, dynamic>? ?? {});
        // Reconnect with the new connection details.
        _obs?.close();
        _connectObs();
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

  void _applySettings(Map<String, dynamic> s) {
    _obsHost = (s['host'] as String?)?.trim().isNotEmpty == true
        ? (s['host'] as String).trim()
        : '127.0.0.1';
    final p = s['port'];
    _obsPort = p is num ? p.toInt() : int.tryParse('${p ?? ''}') ?? 4455;
    _obsPassword = (s['password'] as String?) ?? '';
  }

  void _handleInvoke(Map<String, dynamic> msg) {
    final requestId = msg['requestId'];
    final actionId = msg['actionId'] as String?;
    final fields = msg['fields'] as Map<String, dynamic>? ?? {};

    if (_obs == null) {
      _sendHost({
        'type': 'actionResult',
        'requestId': requestId,
        'success': false,
        'error': 'OBS is not connected',
      });
      return;
    }

    if (actionId == 'set_scene') {
      final scene = fields['scene'] as String?;
      if (scene == null || scene.isEmpty) {
        _sendHost({
          'type': 'actionResult',
          'requestId': requestId,
          'success': false,
          'error': 'No scene selected',
        });
        return;
      }
      _obsRequest('SetCurrentProgramScene', {'sceneName': scene},
          (ok, _) {
        _replyInvoke(requestId, ok, ok ? 'Scene → $scene' : 'OBS rejected scene');
      });
      return;
    }

    final requestType = obsActionRequests[actionId];
    if (requestType == null) {
      _replyInvoke(requestId, false, 'Unknown action: $actionId');
      return;
    }
    _obsRequest(requestType, null, (ok, _) {
      _replyInvoke(requestId, ok, ok ? requestType : 'OBS rejected $requestType');
    });
  }

  void _replyInvoke(dynamic requestId, bool ok, String message) {
    _sendHost({
      'type': 'actionResult',
      'requestId': requestId,
      'success': ok,
      if (ok) 'output': message else 'error': message,
    });
  }

  void _handleRequestList(Map<String, dynamic> msg) {
    final requestId = msg['requestId'];
    final listId = msg['listId'] as String?;
    if (listId != 'scenes' || _obs == null) {
      _sendHost({'type': 'listResult', 'requestId': requestId, 'options': []});
      return;
    }
    _obsRequest('GetSceneList', null, (ok, data) {
      final scenes = (data['scenes'] as List<dynamic>? ?? [])
          .map((s) => (s as Map<String, dynamic>)['sceneName'] as String?)
          .whereType<String>()
          .map((name) => {'value': name, 'label': name})
          .toList();
      _sendHost({
        'type': 'listResult',
        'requestId': requestId,
        'options': scenes,
      });
    });
  }

  void _sendHost(Map<String, dynamic> msg) => _host?.add(jsonEncode(msg));

  void _setState(String id, String value) =>
      _sendHost({'type': 'setState', 'stateId': id, 'value': value});

  void _log(String message) =>
      _sendHost({'type': 'log', 'level': 'info', 'message': '[obs] $message'});

  // --- OBS side ------------------------------------------------------------

  void _connectObs() {
    _obsReconnect?.cancel();
    WebSocket.connect('ws://$_obsHost:$_obsPort')
        .timeout(const Duration(seconds: 4))
        .then((socket) {
      _obs = socket;
      socket.listen(
        (data) => _onObsMessage(data as String),
        onDone: _onObsClosed,
        onError: (_) => _onObsClosed(),
      );
    }).catchError((_) {
      _setState('obs', 'Disconnected');
      _scheduleObsReconnect();
    });
  }

  void _onObsClosed() {
    _obs = null;
    _pending.clear();
    _setState('obs', 'Disconnected');
    _setState('recording', '—');
    _setState('streaming', '—');
    _scheduleObsReconnect();
  }

  void _scheduleObsReconnect() {
    _obsReconnect?.cancel();
    _obsReconnect = Timer(const Duration(seconds: 5), _connectObs);
  }

  void _onObsMessage(String data) {
    final msg = jsonDecode(data) as Map<String, dynamic>;
    final op = msg['op'] as int?;
    final d = msg['d'] as Map<String, dynamic>? ?? {};

    switch (op) {
      case ObsOp.hello:
        final authInfo = d['authentication'] as Map<String, dynamic>?;
        String? auth;
        if (authInfo != null) {
          auth = obsAuthString(
            _obsPassword,
            authInfo['salt'] as String? ?? '',
            authInfo['challenge'] as String? ?? '',
          );
        }
        _sendObsRaw(buildIdentify(auth));
        break;

      case ObsOp.identified:
        _setState('obs', 'Connected');
        _log('connected to OBS');
        _pollInitialStatus();
        break;

      case ObsOp.event:
        final s = stateFromEvent(
            d['eventType'] as String? ?? '', d['eventData'] as Map<String, dynamic>? ?? {});
        if (s != null) _setState(s.id, s.value);
        break;

      case ObsOp.requestResponse:
        final id = d['requestId'] as String?;
        final ok = (d['requestStatus'] as Map<String, dynamic>?)?['result']
                as bool? ??
            false;
        final responseData = d['responseData'] as Map<String, dynamic>? ?? {};
        final cb = _pending.remove(id);
        cb?.call(ok, responseData);
        break;
    }
  }

  /// Sends an OBS request and routes its response to [onResponse].
  void _obsRequest(String type, Map<String, dynamic>? data,
      void Function(bool ok, Map<String, dynamic> data) onResponse) {
    final id = 'r${_reqCounter++}';
    _pending[id] = onResponse;
    _sendObsRaw(buildRequest(type, id, data));
  }

  void _pollInitialStatus() {
    _obsRequest('GetSceneList', null, (ok, data) {
      final scene = data['currentProgramSceneName'] as String?;
      if (scene != null) _setState('scene', scene);
    });
    _obsRequest('GetRecordStatus', null, (ok, data) {
      _setState('recording', recordingLabel(data['outputActive'] as bool? ?? false));
    });
    _obsRequest('GetStreamStatus', null, (ok, data) {
      _setState('streaming', streamingLabel(data['outputActive'] as bool? ?? false));
    });
  }

  void _sendObsRaw(Map<String, dynamic> msg) => _obs?.add(jsonEncode(msg));

  void _shutdown() {
    _obsReconnect?.cancel();
    _obs?.close();
    _host?.close();
    exit(0);
  }
}
