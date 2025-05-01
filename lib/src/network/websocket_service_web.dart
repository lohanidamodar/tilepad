import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/html.dart';

import 'websocket_service.dart';
import '../models/message.dart';
import '../models/client_info.dart';

/// Creates a client WebSocket implementation for web platform
ClientWebSocketService createWebSocketClient() => WebClientWebSocketService();

/// Creates a server WebSocket implementation for web platform
/// Note: This is a stub since servers can't run on web, but it avoids import errors
ServerWebSocketService createWebSocketServer() => WebServerWebSocketService();

/// Web implementation of the client WebSocket service
class WebClientWebSocketService implements ClientWebSocketService {
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
      debugPrint('Web: Attempting to connect to: $address');

      // Close existing connection if any
      await close();

      // Create a web socket connection
      try {
        _channel = HtmlWebSocketChannel.connect(address);
      } catch (e) {
        debugPrint('Web: Immediate connection failure: $e');
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
              debugPrint('Web: Error decoding message: $e');
            }
          }
        },
        onDone: () {
          debugPrint('Web: WebSocket connection closed');
          _isConnected = false;
        },
        onError: (error) {
          debugPrint('Web: WebSocket error: $error');
          _isConnected = false;
        },
      );

      // Wait a short time to ensure connection is established
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        // Check if the connection was dropped during the delay
        if (_channel == null) {
          debugPrint('Web: Connection was closed during initial delay');
          _isConnected = false;
          return false;
        }
      } catch (e) {
        debugPrint('Web: Error during connection verification: $e');
        _isConnected = false;
        return false;
      }

      _isConnected = true;
      debugPrint('Web: Connection established');
      return true;
    } catch (e) {
      _isConnected = false;
      debugPrint('Web: Failed to connect: $e');
      return false;
    }
  }

  @override
  void sendMessage(Message message) {
    if (_channel != null && _isConnected) {
      try {
        _channel!.sink.add(message.encode());
      } catch (e) {
        debugPrint('Web: Error sending message: $e');
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

/// A stub implementation of ServerWebSocketService for web
/// Note: This is only to prevent import errors since servers don't run on web
class WebServerWebSocketService implements ServerWebSocketService {
  final _messageController = StreamController<Message>.broadcast();
  final _clientConnectionController =
      StreamController<ClientConnectionEvent>.broadcast();

  @override
  Stream<Message> get messageStream => _messageController.stream;

  @override
  Stream<ClientConnectionEvent> get clientConnectionStream =>
      _clientConnectionController.stream;

  @override
  List<ClientInfo> get connectedClients => [];

  @override
  Future<bool> start(int port) async {
    debugPrint('Cannot start server on web platform');
    return false;
  }

  @override
  void broadcast(Message message) {
    // No-op on web
  }

  @override
  void sendMessage(Message message) {
    // No-op on web
  }

  @override
  Future<void> close() async {
    await _messageController.close();
    await _clientConnectionController.close();
  }
}
