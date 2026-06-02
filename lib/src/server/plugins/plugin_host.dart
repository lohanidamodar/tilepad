import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'plugin_manifest.dart';
import 'plugin_protocol.dart';
import 'state_store.dart';

/// Result of invoking a plugin action.
class PluginActionResult {
  final bool success;
  final String output;
  final String error;
  PluginActionResult({
    required this.success,
    this.output = '',
    this.error = '',
  });
}

/// One connected plugin: its socket plus the token/settings it was allowed with.
class _PluginConnection {
  final String pluginId;
  final String token;
  Map<String, dynamic> settings;
  WebSocket? socket;
  bool registered = false;

  _PluginConnection(this.pluginId, this.token, this.settings);
}

/// Owns the loopback WebSocket the plugin processes connect to, performs the
/// handshake, routes protocol messages, and exposes [invoke] / [requestList] /
/// [pushSettings] to the rest of the server. Live state lands in [stateStore].
///
/// This class handles the *protocol*; spawning the OS processes is delegated to
/// [PluginProcess] (wired by [MarcoServer]). The two are separated so the
/// protocol can be tested with an in-process fake plugin.
class PluginHost {
  final StateStore stateStore;
  final Duration requestTimeout;
  final _uuid = const Uuid();

  HttpServer? _server;
  int _port = 0;

  /// Plugins allowed to register, keyed by pluginId.
  final Map<String, _PluginConnection> _connections = {};

  /// Pending host->plugin requests awaiting a correlated reply.
  final Map<String, Completer<Map<String, dynamic>>> _pending = {};

  final _connectionChanges = StreamController<String>.broadcast();

  PluginHost({
    StateStore? stateStore,
    this.requestTimeout = const Duration(seconds: 10),
  }) : stateStore = stateStore ?? StateStore();

  /// The actual bound port (useful when started with port 0).
  int get port => _port;

  /// Emits a pluginId whenever its connection state changes.
  Stream<String> get connectionChanges => _connectionChanges.stream;

  bool isConnected(String pluginId) =>
      _connections[pluginId]?.registered ?? false;

  /// Starts the loopback WebSocket server. Returns the bound port.
  Future<int> start({int port = 8091}) async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _port = _server!.port;
    _server!.listen(_handleHttpRequest);
    debugPrint('Plugin host listening on 127.0.0.1:$_port');
    return _port;
  }

  /// Registers a plugin id + one-time token that is permitted to connect, along
  /// with the current settings to hand it on registration.
  void allowPlugin(
    String pluginId,
    String token, {
    Map<String, dynamic> settings = const {},
  }) {
    _connections[pluginId] = _PluginConnection(
      pluginId,
      token,
      Map<String, dynamic>.from(settings),
    );
  }

  /// Stops allowing a plugin, closes its socket, and clears its live state.
  Future<void> disconnect(String pluginId) async {
    final conn = _connections.remove(pluginId);
    if (conn != null) {
      try {
        conn.socket?.add(jsonEncode({'type': PluginProtocol.shutdown}));
        await conn.socket?.close();
      } catch (_) {}
    }
    stateStore.clearPlugin(pluginId);
    _connectionChanges.add(pluginId);
  }

  void _handleHttpRequest(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }
    final socket = await WebSocketTransformer.upgrade(request);
    String? boundPluginId;
    socket.listen(
      (data) {
        if (data is! String) return;
        try {
          final msg = jsonDecode(data) as Map<String, dynamic>;
          boundPluginId =
              _handleMessage(socket, msg, boundPluginId);
        } catch (e) {
          debugPrint('Plugin host: bad message: $e');
        }
      },
      onDone: () => _handleSocketClosed(boundPluginId, socket),
      onError: (e) {
        debugPrint('Plugin host socket error: $e');
        _handleSocketClosed(boundPluginId, socket);
      },
    );
  }

  /// Handles one inbound message, returning the (possibly newly) bound pluginId.
  String? _handleMessage(
    WebSocket socket,
    Map<String, dynamic> msg,
    String? boundPluginId,
  ) {
    final type = msg['type'] as String?;
    switch (type) {
      case PluginProtocol.register:
        return _handleRegister(socket, msg);

      case PluginProtocol.actionResult:
      case PluginProtocol.listResult:
        final requestId = msg['requestId'] as String?;
        final completer = requestId == null ? null : _pending.remove(requestId);
        completer?.complete(msg);
        return boundPluginId;

      case PluginProtocol.setState:
        if (boundPluginId != null) {
          stateStore.set(
            boundPluginId,
            msg['stateId'] as String? ?? '',
            value: msg['value'],
          );
        }
        return boundPluginId;

      case PluginProtocol.setStateImage:
        if (boundPluginId != null) {
          stateStore.set(
            boundPluginId,
            msg['stateId'] as String? ?? '',
            value: msg['value'],
            image: msg['image'] as String?,
          );
        }
        return boundPluginId;

      case PluginProtocol.log:
        debugPrint(
          'Plugin[$boundPluginId] ${msg['level'] ?? 'info'}: ${msg['message']}',
        );
        return boundPluginId;

      default:
        return boundPluginId;
    }
  }

  String? _handleRegister(WebSocket socket, Map<String, dynamic> msg) {
    final pluginId = msg['pluginId'] as String?;
    final token = msg['token'] as String?;
    final conn = pluginId == null ? null : _connections[pluginId];
    if (conn == null || conn.token != token) {
      debugPrint('Plugin host: rejected registration for "$pluginId"');
      socket.close();
      return null;
    }
    conn.socket = socket;
    conn.registered = true;
    socket.add(jsonEncode({
      'type': PluginProtocol.registered,
      'settings': conn.settings,
    }));
    _connectionChanges.add(pluginId!);
    return pluginId;
  }

  void _handleSocketClosed(String? pluginId, WebSocket socket) {
    if (pluginId == null) return;
    final conn = _connections[pluginId];
    if (conn != null && identical(conn.socket, socket)) {
      conn.registered = false;
      conn.socket = null;
      stateStore.clearPlugin(pluginId);
      _connectionChanges.add(pluginId);
    }
  }

  /// Invokes [actionId] on [pluginId] with [fields], awaiting its result.
  Future<PluginActionResult> invoke(
    String pluginId,
    String actionId,
    Map<String, dynamic> fields,
  ) async {
    final conn = _connections[pluginId];
    if (conn == null || !conn.registered || conn.socket == null) {
      return PluginActionResult(
        success: false,
        error: 'Plugin "$pluginId" is not connected',
      );
    }
    try {
      final reply = await _request(conn, {
        'type': PluginProtocol.invoke,
        'actionId': actionId,
        'fields': fields,
      });
      return PluginActionResult(
        success: reply['success'] as bool? ?? false,
        output: reply['output'] as String? ?? '',
        error: reply['error'] as String? ?? '',
      );
    } on TimeoutException {
      return PluginActionResult(
        success: false,
        error: 'Plugin "$pluginId" timed out',
      );
    }
  }

  /// Asks [pluginId] for the dynamic options of [listId].
  Future<List<PluginFieldOption>> requestList(
    String pluginId,
    String listId, {
    Map<String, dynamic> fields = const {},
  }) async {
    final conn = _connections[pluginId];
    if (conn == null || !conn.registered || conn.socket == null) {
      throw StateError('Plugin "$pluginId" is not connected');
    }
    final reply = await _request(conn, {
      'type': PluginProtocol.requestList,
      'listId': listId,
      'fields': fields,
    });
    final options = (reply['options'] as List<dynamic>?) ?? const [];
    return options
        .map((e) => PluginFieldOption.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Pushes updated [settings] to a connected plugin and remembers them.
  void pushSettings(String pluginId, Map<String, dynamic> settings) {
    final conn = _connections[pluginId];
    if (conn == null) return;
    conn.settings = Map<String, dynamic>.from(settings);
    conn.socket?.add(jsonEncode({
      'type': PluginProtocol.settingsUpdated,
      'settings': settings,
    }));
  }

  Future<Map<String, dynamic>> _request(
    _PluginConnection conn,
    Map<String, dynamic> message,
  ) {
    final requestId = _uuid.v4();
    message['requestId'] = requestId;
    final completer = Completer<Map<String, dynamic>>();
    _pending[requestId] = completer;
    conn.socket!.add(jsonEncode(message));
    return completer.future.timeout(
      requestTimeout,
      onTimeout: () {
        _pending.remove(requestId);
        throw TimeoutException('Plugin request timed out', requestTimeout);
      },
    );
  }

  Future<void> stop() async {
    for (final conn in _connections.values) {
      try {
        await conn.socket?.close();
      } catch (_) {}
    }
    _connections.clear();
    await _server?.close(force: true);
    _server = null;
    await _connectionChanges.close();
  }
}
