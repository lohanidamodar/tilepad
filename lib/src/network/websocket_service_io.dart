import 'dart:async';
import 'dart:io';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'websocket_service.dart';
import '../models/message.dart';

/// Creates a client WebSocket implementation for IO platforms (mobile/desktop)
ClientWebSocketService createWebSocketClient() => IOClientWebSocketService();

/// Creates a server WebSocket implementation for IO platforms
ServerWebSocketService createWebSocketServer() => IOServerWebSocketService();

/// IO implementation of the client WebSocket service
class IOClientWebSocketService implements ClientWebSocketService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<Message>.broadcast();
  
  @override
  WebSocketChannel? get channel => _channel;
  
  @override
  Stream<Message> get messageStream => _messageController.stream;

  @override
  Future<bool> connect(String address) async {
    try {
      print('Attempting to connect to: $address');
      
      // Close existing connection if any
      await close();
      
      _channel = IOWebSocketChannel.connect(
        Uri.parse(address),
        pingInterval: const Duration(seconds: 5),
      );
      
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
      
      print('Connection established');
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
  }
}

/// IO implementation of the server WebSocket service
class IOServerWebSocketService implements ServerWebSocketService {
  HttpServer? _server;
  final List<WebSocket> _clients = [];
  final _messageController = StreamController<Message>.broadcast();
  
  @override
  Stream<Message> get messageStream => _messageController.stream;
  
  @override
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
    await _server?.close();
    await _messageController.close();
  }
}