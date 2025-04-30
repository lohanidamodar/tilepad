import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

// Import platform-specific implementations conditionally
import 'websocket_service_io.dart'
    if (dart.library.html) 'websocket_service_web.dart';

import '../models/message.dart';

/// A service for handling WebSocket communications
abstract class WebSocketService {
  /// Stream of messages received from the WebSocket
  Stream<Message> get messageStream;

  /// Sends a message through the WebSocket
  void sendMessage(Message message);

  /// Closes the WebSocket connection
  Future<void> close();
}

/// A client implementation of [WebSocketService] for connecting to a server
abstract class ClientWebSocketService implements WebSocketService {
  /// Factory constructor to create the appropriate implementation based on platform
  factory ClientWebSocketService() => createWebSocketClient();

  /// The WebSocket channel
  WebSocketChannel? get channel;

  /// Connects to a WebSocket server at the given address
  Future<bool> connect(String address);
}

/// A server implementation of [WebSocketService]
abstract class ServerWebSocketService implements WebSocketService {
  /// Factory constructor to create the appropriate implementation
  factory ServerWebSocketService() => createWebSocketServer();

  /// Starts a WebSocket server on the given port
  Future<bool> start(int port);

  /// Sends a message to all clients
  void broadcast(Message message);
}
