import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:marco_deck/src/client/client_providers.dart';
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
  String? _lastConnectedAddress;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _reconnecting = false;
  void Function(bool)? _onReconnectionStateChanged;

  // Connection monitoring
  StreamController<ConnectionStatus>? _connectionStatusController;
  Timer? _connectionMonitorTimer;

  @override
  WebSocketChannel? get channel => _channel;

  @override
  bool get isConnected => _isConnected;

  @override
  bool get isReconnecting => _reconnecting;

  @override
  set onReconnectionStateChanged(void Function(bool) callback) {
    _onReconnectionStateChanged = callback;
  }

  @override
  void cancelReconnection() {
    if (_reconnecting) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _reconnecting = false;
      if (_onReconnectionStateChanged != null) {
        _onReconnectionStateChanged!(false);
      }
    }
  }

  @override
  Stream<Message> get messageStream => _messageController.stream;

  /// Stream of connection status changes
  @override
  Stream<ConnectionStatus> get connectionStatusStream {
    _connectionStatusController ??=
        StreamController<ConnectionStatus>.broadcast();
    return _connectionStatusController!.stream;
  }

  @override
  Future<bool> connect(String address) async {
    try {
      debugPrint('Attempting to connect to: $address');
      _lastConnectedAddress = address;

      // Close existing connection if any
      await close();

      // Create the connection with a shorter timeout
      try {
        _channel = IOWebSocketChannel.connect(
          Uri.parse(address),
          pingInterval: const Duration(seconds: 2),
          connectTimeout: const Duration(
            seconds: 8,
          ), // Add explicit timeout for connection
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

              // If we receive a ping message, respond with a pong
              if (message.type == MessageType.ping) {
                sendMessage(
                  Message(
                    type: MessageType.pong,
                    payload: {
                      'timestamp': DateTime.now().millisecondsSinceEpoch,
                    },
                  ),
                );
              }
            } catch (e) {
              debugPrint('Error decoding message: $e');
            }
          }
        },
        onDone: () {
          debugPrint('WebSocket connection closed');
          _isConnected = false;

          // Notify about disconnection through the status stream
          if (_connectionStatusController != null) {
            _connectionStatusController!.add(ConnectionStatus.disconnected);
          }

          _startReconnectionTimer();
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _isConnected = false;

          // Notify about disconnection through the status stream
          if (_connectionStatusController != null) {
            _connectionStatusController!.add(ConnectionStatus.disconnected);
          }

          _startReconnectionTimer();
        },
      );

      // Wait a short time to ensure connection is established
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        // Check if the connection was dropped during the delay
        if (_channel == null) {
          debugPrint('Connection was closed during initial delay');
          _isConnected = false;
          _startReconnectionTimer();
          return false;
        }

        // Send a test ping to verify the connection is actually working
        try {
          debugPrint('Sending test ping to verify connection');
          _channel!.sink.add(
            Message(
              type: MessageType.ping,
              payload: {'timestamp': DateTime.now().millisecondsSinceEpoch},
            ).encode(),
          );
        } catch (e) {
          debugPrint('Error sending test ping: $e');
          _isConnected = false;
          await _channel?.sink.close();
          _channel = null;
          _startReconnectionTimer();
          return false;
        }
      } catch (e) {
        debugPrint('Error during connection verification: $e');
        _isConnected = false;
        return false;
      }

      _isConnected = true;
      debugPrint('Connection established');

      // If we were reconnecting, notify that we're no longer reconnecting
      if (_reconnecting) {
        _reconnecting = false;
        if (_onReconnectionStateChanged != null) {
          _onReconnectionStateChanged!(false);
        }
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
      }

      // Start ping timer for explicit ping messages
      _startPingTimer();

      // Start connection monitoring
      _startConnectionMonitoring();

      return true;
    } catch (e) {
      _isConnected = false;
      debugPrint('Failed to connect: $e');
      return false;
    }
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_isConnected) {
        try {
          sendMessage(
            Message(
              type: MessageType.ping,
              payload: {'timestamp': DateTime.now().millisecondsSinceEpoch},
            ),
          );
        } catch (e) {
          debugPrint('Error sending ping: $e');
          _isConnected = false;
          _startReconnectionTimer();
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _startReconnectionTimer() {
    if (_reconnecting || _lastConnectedAddress == null) return;

    _reconnecting = true;
    // Notify about reconnection state change
    if (_onReconnectionStateChanged != null) {
      _onReconnectionStateChanged!(true);
    }
    
    // Track reconnection attempts for exponential backoff
    int currentReconnectAttempt = 0;
    final int maxReconnectAttempts = 10;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!_reconnecting) {
        timer.cancel();
        return;
      }
      
      currentReconnectAttempt++;
      
      // Calculate delay based on attempt number (exponential backoff with a cap)
      // This will start at 5 seconds and gradually increase
      final int delaySeconds = currentReconnectAttempt > 5 
          ? 20  // Cap at 20 seconds max delay
          : 5 * currentReconnectAttempt;
      
      debugPrint('Reconnection attempt $currentReconnectAttempt of $maxReconnectAttempts (delay: ${delaySeconds}s)');
      
      // Notify status update with current attempt info via reconnection state change
      if (_onReconnectionStateChanged != null) {
        _onReconnectionStateChanged!(true);
      }
      
      if (_connectionStatusController != null) {
        _connectionStatusController!.add(ConnectionStatus.reconnecting);
      }

      try {
        final success = await connect(_lastConnectedAddress!);
        if (success) {
          debugPrint('Reconnection successful');
          timer.cancel();
          _reconnecting = false;
          if (_onReconnectionStateChanged != null) {
            _onReconnectionStateChanged!(false);
          }
        } else {
          // Don't attempt to reconnect again immediately
          // The timer will trigger the next attempt after the specified delay
          debugPrint('Reconnection attempt failed, waiting ${delaySeconds}s before next attempt');
          
          // If we've reached the maximum number of attempts, stop reconnecting
          if (currentReconnectAttempt >= maxReconnectAttempts) {
            debugPrint('Maximum reconnection attempts reached, giving up');
            timer.cancel();
            _reconnecting = false;
            if (_onReconnectionStateChanged != null) {
              _onReconnectionStateChanged!(false);
            }
          }
        }
      } catch (e) {
        debugPrint('Reconnection attempt failed: $e');
        // Don't attempt to reconnect again immediately
        // Let the timer handle the next attempt after delay
      }
    });
  }

  /// Monitor connection health periodically
  void _startConnectionMonitoring() {
    _connectionMonitorTimer?.cancel();
    _connectionMonitorTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) {
      if (!_isConnected && _connectionStatusController != null) {
        // If we're not connected, emit a disconnected status
        _connectionStatusController!.add(ConnectionStatus.disconnected);
      }
    });
  }

  /// Stop connection monitoring
  void _stopConnectionMonitoring() {
    _connectionMonitorTimer?.cancel();
    _connectionMonitorTimer = null;
  }

  @override
  void sendMessage(Message message) {
    if (_channel != null && _isConnected) {
      try {
        _channel!.sink.add(message.encode());
      } catch (e) {
        debugPrint('Error sending message: $e');
        _isConnected = false;
        _startReconnectionTimer();
      }
    }
  }

  @override
  Future<void> close() async {
    debugPrint('Closing WebSocket connection and cleaning up resources');
    _isConnected = false;

    // Cancel all timers
    _pingTimer?.cancel();
    _pingTimer = null;

    // Cancel reconnection
    cancelReconnection();

    // Stop connection monitoring
    _stopConnectionMonitoring();

    // Close the channel properly
    try {
      await _channel?.sink.close(
        WebSocketStatus.normalClosure,
        'Connection closed by client',
      );
    } catch (e) {
      debugPrint('Error closing WebSocket channel: $e');
    } finally {
      _channel = null;
      _lastConnectedAddress = null; // Reset the address to ensure a clean state
    }
  }
}

/// IO implementation of the server WebSocket service
class IOServerWebSocketService implements ServerWebSocketService {
  HttpServer? _server;
  final List<WebSocket> _clients = [];
  final Map<WebSocket, ClientInfo> _clientInfo = {};
  final Map<WebSocket, DateTime> _lastPongReceived = {};
  final _messageController = StreamController<Message>.broadcast();
  final _clientConnectionController =
      StreamController<ClientConnectionEvent>.broadcast();
  Timer? _pingTimer;

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

      // Start ping timer to check client connections
      _startPingTimer();

      return true;
    } catch (e) {
      debugPrint('Failed to start server: $e');
      return false;
    }
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _pingClients();
      _checkClientTimeouts();
    });
  }

  void _pingClients() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final pingMessage =
        Message(
          type: MessageType.ping,
          payload: {'timestamp': timestamp},
        ).encode();

    for (var client in [..._clients]) {
      try {
        client.add(pingMessage);
      } catch (e) {
        debugPrint('Error pinging client: $e');
        _handleClientDisconnection(client);
      }
    }
  }

  void _checkClientTimeouts() {
    final now = DateTime.now();
    final timeout = const Duration(seconds: 10); // Allow for some network delay

    for (var client in [..._clients]) {
      final lastPong = _lastPongReceived[client];
      if (lastPong != null) {
        final elapsed = now.difference(lastPong);
        if (elapsed > timeout) {
          debugPrint('Client timed out: ${_clientInfo[client]?.id}');
          _handleClientDisconnection(client);
        }
      }
    }
  }

  void _handleClientConnection(WebSocket client, [HttpRequest? request]) {
    debugPrint('Client connected');
    _clients.add(client);

    // Create and store client info
    final clientInfo = ClientInfo.fromWebSocket(client, request);
    _clientInfo[client] = clientInfo;

    // Initialize last pong timestamp
    _lastPongReceived[client] = DateTime.now();

    // Emit client connected event
    _clientConnectionController.add(
      ClientConnectionEvent(clientInfo: clientInfo, connected: true),
    );

    client.listen(
      (dynamic data) {
        if (data is String) {
          try {
            final message = Message.decode(data);

            // Update last pong time if this is a pong message
            if (message.type == MessageType.pong) {
              _lastPongReceived[client] = DateTime.now();
            } else {
              _messageController.add(message);
            }
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
    _lastPongReceived.remove(client);

    // Close the client socket
    try {
      client.close();
    } catch (e) {
      // Socket already closed, ignore
    }

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
    for (var client in [..._clients]) {
      try {
        client.add(encodedMessage);
      } catch (e) {
        debugPrint('Error broadcasting to client: $e');
        _handleClientDisconnection(client);
      }
    }
  }

  @override
  Future<void> close() async {
    _pingTimer?.cancel();

    for (var client in [..._clients]) {
      try {
        await client.close();
      } catch (e) {
        // Ignore errors when closing
      }
    }
    _clients.clear();
    _clientInfo.clear();
    _lastPongReceived.clear();

    await _server?.close();
  }
}
