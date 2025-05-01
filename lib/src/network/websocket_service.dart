import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

// Import platform-specific implementations conditionally
import 'websocket_service_io.dart'
    if (dart.library.html) 'websocket_service_web.dart';

import '../models/message.dart';
import '../models/client_info.dart';

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

  /// Whether the client is currently connected to a server
  bool get isConnected;
}

/// A server implementation of [WebSocketService]
abstract class ServerWebSocketService implements WebSocketService {
  /// Factory constructor to create the appropriate implementation
  factory ServerWebSocketService() => createWebSocketServer();

  /// Starts a WebSocket server on the given port
  Future<bool> start(int port);

  /// Sends a message to all clients
  void broadcast(Message message);

  /// Gets a list of connected clients
  List<ClientInfo> get connectedClients;

  /// Stream of client connection events (connect/disconnect)
  Stream<ClientConnectionEvent> get clientConnectionStream;
}

/// Event for client connections and disconnections
class ClientConnectionEvent {
  /// The client info
  final ClientInfo clientInfo;

  /// Whether the client connected (true) or disconnected (false)
  final bool connected;

  /// Creates a new client connection event
  ClientConnectionEvent({required this.clientInfo, required this.connected});
}
