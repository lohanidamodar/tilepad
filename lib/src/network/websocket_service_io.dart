import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'websocket_service.dart';
import '../models/message.dart';
import '../models/client_info.dart';

/// Creates a client WebSocket implementation for IO platforms (mobile/desktop)
ClientWebSocketService createWebSocketClient() => IOClientWebSocketService();

/// Creates a server WebSocket implementation for IO platforms
ServerWebSocketService createWebSocketServer() => IOServerWebSocketService();

/// IO implementation of the client WebSocket service
class IOClientWebSocketService implements ClientWebSocketService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<Message>.broadcast();
  bool _isConnected = false;

  @override
  WebSocketChannel? get channel => _channel;

  @override
  bool get isConnected => _isConnected;

  @override
  Stream<Message> get messageStream => _messageController.stream;

  @override
  Future<bool> connect(String address) async {
    try {
      debugPrint('Attempting to connect to: $address');

      // Close existing connection if any
      await close();

      // Create the connection
      try {
        _channel = IOWebSocketChannel.connect(
          Uri.parse(address),
          pingInterval: const Duration(seconds: 5),
        );
      } catch (e) {
        // Handle immediate connection failures
        debugPrint('Immediate connection failure: $e');
        _isConnected = false;
        return false;
      }

      // Set up the connection listener
      _channel!.stream.listen(
        (dynamic data) {
          if (data is String) {
            try {
              final message = Message.decode(data);
              _messageController.add(message);
            } catch (e) {
              debugPrint('Error decoding message: $e');
            }
          }
        },
        onDone: () {
          debugPrint('WebSocket connection closed');
          _isConnected = false;
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _isConnected = false;
        },
      );

      // Wait a short time to ensure connection is established
      // Try to get an initial message or response to validate the connection
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        // Check if the connection was dropped during the delay
        if (_channel == null) {
          debugPrint('Connection was closed during initial delay');
          _isConnected = false;
          return false;
        }
      } catch (e) {
        debugPrint('Error during connection verification: $e');
        _isConnected = false;
        return false;
      }

      _isConnected = true;
      debugPrint('Connection established');
      return true;
    } catch (e) {
      _isConnected = false;
      debugPrint('Failed to connect: $e');
      return false;
    }
  }

  @override
  void sendMessage(Message message) {
    if (_channel != null && _isConnected) {
      try {
        _channel!.sink.add(message.encode());
      } catch (e) {
        debugPrint('Error sending message: $e');
        _isConnected = false;
      }
    }
  }

  @override
  Future<void> close() async {
    _isConnected = false;
    await _channel?.sink.close();
    _channel = null;
  }
}

/// IO implementation of the server WebSocket service
class IOServerWebSocketService implements ServerWebSocketService {
  HttpServer? _server;
  final List<WebSocket> _clients = [];
  final Map<WebSocket, ClientInfo> _clientInfo = {};
  final _messageController = StreamController<Message>.broadcast();
  final _clientConnectionController =
      StreamController<ClientConnectionEvent>.broadcast();

  @override
  Stream<Message> get messageStream => _messageController.stream;

  @override
  Stream<ClientConnectionEvent> get clientConnectionStream =>
      _clientConnectionController.stream;

  @override
  List<ClientInfo> get connectedClients => _clientInfo.values.toList();

  @override
  Future<bool> start(int port) async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      debugPrint('WebSocket server listening on port $port');

      _server!.listen((HttpRequest request) {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          WebSocketTransformer.upgrade(request).then((WebSocket socket) {
            _handleClientConnection(socket, request);
          });
        } else {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.close();
        }
      });

      return true;
    } catch (e) {
      debugPrint('Failed to start server: $e');
      return false;
    }
  }

  void _handleClientConnection(WebSocket client, [HttpRequest? request]) {
    debugPrint('Client connected');
    _clients.add(client);

    // Create and store client info
    final clientInfo = ClientInfo.fromWebSocket(client, request);
    _clientInfo[client] = clientInfo;

    // Emit client connected event
    _clientConnectionController.add(
      ClientConnectionEvent(clientInfo: clientInfo, connected: true),
    );

    client.listen(
      (dynamic data) {
        if (data is String) {
          try {
            final message = Message.decode(data);
            _messageController.add(message);
          } catch (e) {
            debugPrint('Error decoding message: $e');
          }
        }
      },
      onDone: () {
        debugPrint('Client disconnected');
        _handleClientDisconnection(client);
      },
      onError: (error) {
        debugPrint('Error from client: $error');
        _handleClientDisconnection(client);
      },
    );
  }

  void _handleClientDisconnection(WebSocket client) {
    // Get client info before removing from map
    final clientInfo = _clientInfo[client];

    // Remove client
    _clients.remove(client);
    _clientInfo.remove(client);

    // Emit client disconnected event if we had info about this client
    if (clientInfo != null) {
      _clientConnectionController.add(
        ClientConnectionEvent(clientInfo: clientInfo, connected: false),
      );
    }
  }

  @override
  void sendMessage(Message message) {
    broadcast(message);
  }

  @override
  void broadcast(Message message) {
    final encodedMessage = message.encode();
    for (var client in _clients) {
      client.add(encodedMessage);
    }
  }

  @override
  Future<void> close() async {
    for (var client in [..._clients]) {
      await client.close();
    }
    _clients.clear();
    _clientInfo.clear();

    await _server?.close();
  }
}
