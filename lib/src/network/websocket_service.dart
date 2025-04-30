import 'dart:async';
import 'dart:io';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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
class ClientWebSocketService implements WebSocketService {
  /// The WebSocket channel
  WebSocketChannel? _channel;

  /// Controller for the message stream
  final _messageController = StreamController<Message>.broadcast();

  @override
  Stream<Message> get messageStream => _messageController.stream;

  /// Connects to a WebSocket server at the given address
  Future<bool> connect(String address) async {
    try {
      _channel = IOWebSocketChannel.connect(
        Uri.parse(address),
        pingInterval: const Duration(seconds: 5),
      );

      _channel!.stream.listen(
        (dynamic data) {
          if (data is String) {
            try {
              final message = Message.decode(data);
              _messageController.add(message);
            } catch (e) {
              print('Error decoding message: $e');
            }
          }
        },
        onDone: () {
          print('WebSocket connection closed');
        },
        onError: (error) {
          print('WebSocket error: $error');
        },
      );

      return true;
    } catch (e) {
      print('Failed to connect: $e');
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
    await _messageController.close();
  }
}

/// A server implementation of [WebSocketService]
class ServerWebSocketService implements WebSocketService {
  /// The WebSocket server
  HttpServer? _server;

  /// List of client connections
  final List<WebSocket> _clients = [];

  /// Controller for the message stream
  final _messageController = StreamController<Message>.broadcast();

  @override
  Stream<Message> get messageStream => _messageController.stream;

  /// Starts a WebSocket server on the given port
  Future<bool> start(int port) async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      print('WebSocket server listening on port $port');

      _server!.listen((HttpRequest request) {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          WebSocketTransformer.upgrade(request).then((WebSocket socket) {
            _handleClientConnection(socket);
          });
        } else {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.close();
        }
      });

      return true;
    } catch (e) {
      print('Failed to start server: $e');
      return false;
    }
  }

  /// Handles a new client connection
  void _handleClientConnection(WebSocket client) {
    print('Client connected');
    _clients.add(client);

    client.listen(
      (dynamic data) {
        if (data is String) {
          try {
            final message = Message.decode(data);
            _messageController.add(message);
          } catch (e) {
            print('Error decoding message: $e');
          }
        }
      },
      onDone: () {
        print('Client disconnected');
        _clients.remove(client);
      },
      onError: (error) {
        print('Error from client: $error');
        _clients.remove(client);
      },
    );
  }

  @override
  void sendMessage(Message message) {
    final encodedMessage = message.encode();
    for (var client in _clients) {
      client.add(encodedMessage);
    }
  }

  /// Sends a message to a specific client
  void sendMessageToClient(WebSocket client, Message message) {
    client.add(message.encode());
  }

  @override
  Future<void> close() async {
    for (var client in [..._clients]) {
      await client.close();
    }
    _clients.clear();
    await _server?.close();
    await _messageController.close();
  }
}
