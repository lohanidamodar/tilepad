import 'dart:async';
import 'dart:io';
import 'dart:math';
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

/// Enhanced IO implementation of the client WebSocket service with improved reliability
class IOClientWebSocketService implements ClientWebSocketService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<Message>.broadcast();
  bool _isConnected = false;
  String? _lastConnectedAddress;
  Timer? _reconnectTimer;
  Timer? _healthCheckTimer;
  bool _reconnecting = false;
  void Function(bool)? _onReconnectionStateChanged;

  // Enhanced connection monitoring
  StreamController<ConnectionStatus>? _connectionStatusController;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 15; // Increased for better persistence
  DateTime? _lastPingTime;
  bool _awaitingPong = false;

  // Adaptive reconnection timing
  static const int _baseReconnectDelay = 1000; // 1 second
  static const int _maxReconnectDelay = 30000; // 30 seconds
  static const double _backoffMultiplier = 1.5;

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
      _reconnectAttempts = 0;

      if (_onReconnectionStateChanged != null) {
        _onReconnectionStateChanged!(false);
      }

      if (_connectionStatusController != null) {
        _connectionStatusController!.add(ConnectionStatus.disconnected);
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
      _reconnectAttempts = 0;

      // Notify connecting status
      if (_connectionStatusController != null) {
        _connectionStatusController!.add(ConnectionStatus.connecting);
      }

      // Close existing connection if any
      await close();

      // Create the connection with enhanced timeout handling
      try {
        _channel = IOWebSocketChannel.connect(
          Uri.parse(address),
          // Don't use automatic pingInterval - we handle health checks manually
          connectTimeout: const Duration(seconds: 10),
        );
      } catch (e) {
        debugPrint('Immediate connection failure: $e');
        _isConnected = false;

        if (_connectionStatusController != null) {
          _connectionStatusController!.add(ConnectionStatus.error);
        }

        return false;
      }

      // Set up enhanced connection listener
      _channel!.stream.listen(
        (dynamic data) {
          if (data is String) {
            try {
              final message = Message.decode(data);

              // Handle different message types
              switch (message.type) {
                case MessageType.ping:
                  // Respond to ping immediately
                  _sendPong();
                  break;
                case MessageType.pong:
                  // Update pong reception time
                  _awaitingPong = false;
                  debugPrint('Received pong - connection healthy');
                  break;
                default:
                  // Forward other messages
                  _messageController.add(message);
                  break;
              }
            } catch (e) {
              debugPrint('Error decoding message: $e');
            }
          }
        },
        onDone: () {
          debugPrint('WebSocket connection closed gracefully');
          _handleDisconnection();
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _handleDisconnection();
        },
      );

      // Enhanced connection verification with timeout
      final connectionSuccess = await _verifyConnection();

      if (connectionSuccess) {
        _isConnected = true;
        _reconnectAttempts = 0;
        debugPrint('Connection established successfully');

        // Reset reconnection state
        if (_reconnecting) {
          _reconnecting = false;
          if (_onReconnectionStateChanged != null) {
            _onReconnectionStateChanged!(false);
          }
          _reconnectTimer?.cancel();
          _reconnectTimer = null;
        }

        // Start health monitoring
        _startHealthCheck();

        if (_connectionStatusController != null) {
          _connectionStatusController!.add(ConnectionStatus.connected);
        }

        return true;
      } else {
        _isConnected = false;
        await _channel?.sink.close();
        _channel = null;

        if (_connectionStatusController != null) {
          _connectionStatusController!.add(ConnectionStatus.error);
        }

        return false;
      }
    } catch (e) {
      _isConnected = false;
      debugPrint('Failed to connect: $e');

      if (_connectionStatusController != null) {
        _connectionStatusController!.add(ConnectionStatus.error);
      }

      return false;
    }
  }

  /// Enhanced connection verification with timeout
  Future<bool> _verifyConnection() async {
    try {
      // Wait briefly for connection to stabilize
      await Future.delayed(const Duration(milliseconds: 500));

      // Check if channel is still available
      if (_channel == null) {
        debugPrint('Channel closed during verification');
        return false;
      }

      // Simply verify the channel is open - don't require immediate pong response
      // The health check will handle ongoing connectivity monitoring
      debugPrint('Connection channel established');
      return true;

      /* Removed aggressive verification ping
      // Send verification ping with timeout
      final verificationCompleter = Completer<bool>();
      Timer? verificationTimeout;

      // Set up timeout
      verificationTimeout = Timer(const Duration(seconds: 5), () {
        if (!verificationCompleter.isCompleted) {
          verificationCompleter.complete(false);
        }
      });

      */

      /* Old verification code removed - using simple channel check above */
    } catch (e) {
      debugPrint('Error during connection verification: $e');
      return false;
    }
  }

  /// Handle disconnection with enhanced retry logic
  void _handleDisconnection() {
    _isConnected = false;
    _stopHealthCheck();

    if (_connectionStatusController != null) {
      _connectionStatusController!.add(ConnectionStatus.disconnected);
    }

    // Start enhanced reconnection if we have an address to reconnect to
    if (_lastConnectedAddress != null && !_reconnecting) {
      _startEnhancedReconnection();
    }
  }

  /// Enhanced reconnection with adaptive backoff
  void _startEnhancedReconnection() {
    if (_reconnecting || _lastConnectedAddress == null) return;

    _reconnecting = true;

    if (_onReconnectionStateChanged != null) {
      _onReconnectionStateChanged!(true);
    }

    if (_connectionStatusController != null) {
      _connectionStatusController!.add(ConnectionStatus.reconnecting);
    }

    _scheduleReconnection();
  }

  /// Schedule the next reconnection attempt with adaptive delay
  void _scheduleReconnection() {
    if (!_reconnecting || _reconnectAttempts >= _maxReconnectAttempts) {
      if (_reconnectAttempts >= _maxReconnectAttempts) {
        debugPrint('Maximum reconnection attempts reached');
        _reconnecting = false;

        if (_onReconnectionStateChanged != null) {
          _onReconnectionStateChanged!(false);
        }

        if (_connectionStatusController != null) {
          _connectionStatusController!.add(ConnectionStatus.disconnected);
        }
      }
      return;
    }

    // Calculate adaptive delay
    final delay = _calculateReconnectDelay(_reconnectAttempts);

    debugPrint(
      'Scheduling reconnection attempt ${_reconnectAttempts + 1}/$_maxReconnectAttempts in ${delay}ms',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delay), () async {
      if (!_reconnecting) return;

      _reconnectAttempts++;

      debugPrint(
        'Attempting reconnection $_reconnectAttempts/$_maxReconnectAttempts to $_lastConnectedAddress',
      );

      final success = await connect(_lastConnectedAddress!);

      if (!success && _reconnecting) {
        // Schedule next attempt
        _scheduleReconnection();
      }
    });
  }

  /// Calculate adaptive reconnection delay
  int _calculateReconnectDelay(int attemptNumber) {
    // Exponential backoff with jitter
    final baseDelay =
        _baseReconnectDelay * pow(_backoffMultiplier, attemptNumber);
    final cappedDelay = min(baseDelay, _maxReconnectDelay.toDouble()).toInt();

    // Add jitter (±25%)
    final jitter =
        (cappedDelay * 0.25 * (Random().nextDouble() * 2 - 1)).toInt();

    return cappedDelay + jitter;
  }

  /// Start health check monitoring
  void _startHealthCheck() {
    _stopHealthCheck();

    // First health check after 20 seconds, then every 30 seconds
    Timer(const Duration(seconds: 20), () {
      if (_isConnected) {
        _performHealthCheck();
      }
    });

    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_isConnected) {
        timer.cancel();
        return;
      }

      _performHealthCheck();
    });
  }

  /// Stop health check monitoring
  void _stopHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  /// Perform health check by sending ping
  void _performHealthCheck() {
    if (!_isConnected || _channel == null) return;

    try {
      // Check if we're awaiting a pong for too long
      if (_awaitingPong && _lastPingTime != null) {
        final timeSinceLastPing = DateTime.now().difference(_lastPingTime!);
        if (timeSinceLastPing.inSeconds > 45) {
          debugPrint('Health check failed - no pong received for 45 seconds');
          _handleDisconnection();
          return;
        } else if (timeSinceLastPing.inSeconds > 30) {
          debugPrint(
            'Warning: Waiting for pong ${timeSinceLastPing.inSeconds}s',
          );
        }
      }

      // Send ping if not awaiting pong
      if (!_awaitingPong) {
        _sendPing();
      }
    } catch (e) {
      debugPrint('Error during health check: $e');
      _handleDisconnection();
    }
  }

  /// Send ping message
  void _sendPing() {
    try {
      _lastPingTime = DateTime.now();
      _awaitingPong = true;

      sendMessage(
        Message(
          type: MessageType.ping,
          payload: {'timestamp': DateTime.now().millisecondsSinceEpoch},
        ),
      );
    } catch (e) {
      debugPrint('Error sending ping: $e');
      _handleDisconnection();
    }
  }

  /// Send pong message
  void _sendPong() {
    try {
      sendMessage(
        Message(
          type: MessageType.pong,
          payload: {'timestamp': DateTime.now().millisecondsSinceEpoch},
        ),
      );
    } catch (e) {
      debugPrint('Error sending pong: $e');
    }
  }

  @override
  void sendMessage(Message message) {
    if (_channel != null && _isConnected) {
      try {
        _channel!.sink.add(message.encode());
      } catch (e) {
        debugPrint('Error sending message: $e');
        _handleDisconnection();
      }
    } else {
      debugPrint('Cannot send message - not connected');
    }
  }

  @override
  Future<void> close() async {
    debugPrint('Closing WebSocket connection');

    // Cancel all timers
    _stopHealthCheck();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    // Reset reconnection state
    _reconnecting = false;
    _reconnectAttempts = 0;
    _awaitingPong = false;
    _lastPingTime = null;

    // Mark as not connected
    _isConnected = false;

    // Close the WebSocket channel
    if (_channel != null) {
      try {
        await _channel!.sink.close();
      } catch (e) {
        debugPrint('Error closing channel: $e');
      }
      _channel = null;
    }

    // Notify disconnection
    if (_connectionStatusController != null) {
      _connectionStatusController!.add(ConnectionStatus.disconnected);
    }

    _isConnected = false;

    if (_connectionStatusController != null) {
      _connectionStatusController!.add(ConnectionStatus.disconnected);
    }
  }

  /// Dispose of resources
  void dispose() {
    close();
    _messageController.close();
    _connectionStatusController?.close();
  }
}

/// IO implementation of the server WebSocket service
class IOServerWebSocketService implements ServerWebSocketService {
  HttpServer? _server;
  final List<WebSocket> _clients = [];
  final List<ClientInfo> _connectedClients = [];
  final _messageController = StreamController<Message>.broadcast();
  final _clientConnectionController =
      StreamController<ClientConnectionEvent>.broadcast();

  @override
  Stream<Message> get messageStream => _messageController.stream;

  @override
  Stream<ClientConnectionEvent> get clientConnectionStream =>
      _clientConnectionController.stream;

  @override
  List<ClientInfo> get connectedClients => List.unmodifiable(_connectedClients);

  @override
  Future<bool> start(int port) async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      debugPrint('Server started on port $port');

      _server!.listen((HttpRequest request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          final webSocket = await WebSocketTransformer.upgrade(request);

          // Get actual client IP address from the request
          final clientIp =
              request.connectionInfo?.remoteAddress.address ?? 'Unknown';

          // Check if a client with this IP already exists
          final existingClientIndex = _connectedClients.indexWhere(
            (client) => client.ipAddress == clientIp,
          );

          ClientInfo clientInfo;
          if (existingClientIndex >= 0) {
            // Reuse existing client info but remove old WebSocket
            clientInfo = _connectedClients[existingClientIndex];
            debugPrint(
              'Client reconnecting from: $clientIp (reusing existing client info)',
            );

            // Remove old WebSocket if it exists
            if (existingClientIndex < _clients.length) {
              try {
                await _clients[existingClientIndex].close();
              } catch (e) {
                debugPrint('Error closing old WebSocket: $e');
              }
              _clients[existingClientIndex] = webSocket;
            } else {
              _clients.add(webSocket);
            }
          } else {
            // New client
            clientInfo = ClientInfo(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              ipAddress: clientIp,
              connectedAt: DateTime.now(),
            );
            _clients.add(webSocket);
            _connectedClients.add(clientInfo);
            debugPrint('New client connected from: $clientIp');
          }

          // Send connection event (after websocket is fully set up)
          // Small delay to ensure websocket listener is attached before events fire
          Future.delayed(const Duration(milliseconds: 100), () {
            _clientConnectionController.add(
              ClientConnectionEvent(clientInfo: clientInfo, connected: true),
            );
          });

          webSocket.listen(
            (data) {
              if (data is String) {
                try {
                  final message = Message.decode(data);

                  // Handle connect message to update device name
                  if (message.type == MessageType.connect) {
                    debugPrint(
                      'Received connect message with payload: ${message.payload}',
                    );
                    if (message.payload != null &&
                        message.payload is Map &&
                        message.payload['deviceName'] != null) {
                      // Update client info with device name
                      final index = _connectedClients.indexOf(clientInfo);
                      debugPrint(
                        'Client index in list: $index, total clients: ${_connectedClients.length}',
                      );
                      if (index >= 0) {
                        final newClientInfo = ClientInfo(
                          id: clientInfo.id,
                          ipAddress: clientInfo.ipAddress,
                          connectedAt: clientInfo.connectedAt,
                          deviceName: message.payload['deviceName'],
                        );
                        _connectedClients[index] = newClientInfo;
                        debugPrint(
                          'Updated client info - Device: ${newClientInfo.deviceName}, IP: ${newClientInfo.ipAddress}',
                        );
                        // Notify of updated client info
                        _clientConnectionController.add(
                          ClientConnectionEvent(
                            clientInfo: newClientInfo,
                            connected: true,
                          ),
                        );
                        debugPrint(
                          'Sent client connection event with updated name',
                        );
                      } else {
                        debugPrint(
                          'WARNING: Client not found in connected clients list!',
                        );
                      }
                    } else {
                      debugPrint(
                        'WARNING: Connect message missing deviceName in payload',
                      );
                    }

                    // Send acknowledgment back to the client
                    try {
                      webSocket.add(
                        Message(type: MessageType.connectAck).encode(),
                      );
                      debugPrint(
                        'Sent connectAck to client ${clientInfo.ipAddress}',
                      );
                    } catch (e) {
                      debugPrint('Error sending connectAck: $e');
                    }

                    // Also add to message stream for app-level handling
                    _messageController.add(message);
                  } else if (message.type == MessageType.ping) {
                    // Respond to ping with pong
                    try {
                      final pongMessage = Message(
                        type: MessageType.pong,
                        payload: {
                          'timestamp': DateTime.now().millisecondsSinceEpoch,
                        },
                      );
                      webSocket.add(pongMessage.encode());
                      debugPrint(
                        'Responded to ping from ${clientInfo.ipAddress}',
                      );
                    } catch (e) {
                      debugPrint('Error sending pong: $e');
                    }
                  } else if (message.type == MessageType.disconnect) {
                    // Client is intentionally disconnecting
                    debugPrint(
                      'Client ${clientInfo.ipAddress} sent disconnect message',
                    );
                    // Close the WebSocket cleanly (don't await in non-async callback)
                    webSocket.close().catchError((e) {
                      debugPrint(
                        'Error closing WebSocket after disconnect: $e',
                      );
                    });
                    // Note: onDone handler will handle cleanup
                  } else if (message.type == MessageType.pong) {
                    // Client responded to our ping
                    debugPrint('Received pong from ${clientInfo.ipAddress}');
                  } else {
                    // Forward other messages to the message stream
                    _messageController.add(message);
                  }
                } catch (e) {
                  debugPrint('Error decoding message: $e');
                }
              }
            },
            onDone: () {
              debugPrint(
                'WebSocket connection closed for ${clientInfo.ipAddress}',
              );

              // Find and remove this specific WebSocket
              final wsIndex = _clients.indexOf(webSocket);
              if (wsIndex >= 0) {
                _clients.removeAt(wsIndex);

                // Find the matching client by IP address
                final clientIndex = _connectedClients.indexWhere(
                  (c) => c.ipAddress == clientInfo.ipAddress,
                );

                if (clientIndex >= 0) {
                  final removedClient = _connectedClients[clientIndex];
                  _connectedClients.removeAt(clientIndex);
                  debugPrint(
                    'Removed client: ${removedClient.deviceName ?? "Unknown Device"} (${removedClient.ipAddress})',
                  );
                  _clientConnectionController.add(
                    ClientConnectionEvent(
                      clientInfo: removedClient,
                      connected: false,
                    ),
                  );
                } else {
                  debugPrint(
                    'Warning: Client ${clientInfo.ipAddress} not found in connected clients list',
                  );
                }
              }
            },
            onError: (error) {
              debugPrint('Client error from ${clientInfo.ipAddress}: $error');

              // Remove WebSocket
              _clients.remove(webSocket);

              // Find and remove client by IP address
              final clientIndex = _connectedClients.indexWhere(
                (c) => c.ipAddress == clientInfo.ipAddress,
              );

              if (clientIndex >= 0) {
                final removedClient = _connectedClients[clientIndex];
                _connectedClients.removeAt(clientIndex);
                _clientConnectionController.add(
                  ClientConnectionEvent(
                    clientInfo: removedClient,
                    connected: false,
                  ),
                );
              }
            },
          );
        }
      });

      return true;
    } catch (e) {
      debugPrint('Failed to start server: $e');
      return false;
    }
  }

  @override
  void sendMessage(Message message) {
    final encodedMessage = message.encode();
    final clientsToRemove = <WebSocket>[];

    for (final client in _clients) {
      try {
        client.add(encodedMessage);
      } catch (e) {
        debugPrint('Error sending message to client: $e');
        clientsToRemove.add(client);
      }
    }

    // Remove clients that couldn't receive the message
    for (final client in clientsToRemove) {
      _clients.remove(client);
    }
  }

  @override
  void broadcast(Message message) {
    sendMessage(message);
  }

  @override
  Future<void> close() async {
    for (final client in _clients) {
      try {
        await client.close();
      } catch (e) {
        debugPrint('Error closing client connection: $e');
      }
    }
    _clients.clear();
    _connectedClients.clear();

    if (_server != null) {
      await _server!.close();
      _server = null;
    }
  }
}
