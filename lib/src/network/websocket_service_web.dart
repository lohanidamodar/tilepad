import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/html.dart';

import 'websocket_service.dart';
import '../models/message.dart';

/// Creates a client WebSocket implementation for web platform
ClientWebSocketService createWebSocketClient() => WebClientWebSocketService();

/// Creates a server WebSocket implementation for web platform
/// Note: This is a stub since servers can't run on web, but it avoids import errors
ServerWebSocketService createWebSocketServer() => WebServerWebSocketService();

/// Web implementation of the client WebSocket service
class WebClientWebSocketService implements ClientWebSocketService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<Message>.broadcast();
  
  @override
  WebSocketChannel? get channel => _channel;
  
  @override
  Stream<Message> get messageStream => _messageController.stream;

  @override
  Future<bool> connect(String address) async {
    try {
      print('Web: Attempting to connect to: $address');
      
      // Close existing connection if any
      await close();
      
      // Create a web socket connection
      _channel = HtmlWebSocketChannel.connect(address);
      
      // Wait a short time to ensure connection is established
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Set up the connection listener
      _channel!.stream.listen(
        (dynamic data) {
          if (data is String) {
            try {
              final message = Message.decode(data);
              _messageController.add(message);
            } catch (e) {
              print('Web: Error decoding message: $e');
            }
          }
        },
        onDone: () {
          print('Web: WebSocket connection closed');
        },
        onError: (error) {
          print('Web: WebSocket error: $error');
        },
      );
      
      print('Web: Connection established');
      return true;
    } catch (e) {
      print('Web: Failed to connect: $e');
      return false;
    }
  }
  
  @override
  void sendMessage(Message message) {
    if (_channel != null) {
      _channel!.sink.add(message.encode());
    }
  }
  
  @override
  Future<void> close() async {
    await _channel?.sink.close();
  }
}

/// A stub implementation of ServerWebSocketService for web
/// Note: This is only to prevent import errors since servers don't run on web
class WebServerWebSocketService implements ServerWebSocketService {
  final _messageController = StreamController<Message>.broadcast();
  
  @override
  Stream<Message> get messageStream => _messageController.stream;
  
  @override
  Future<bool> start(int port) async {
    print('Cannot start server on web platform');
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
  }
}