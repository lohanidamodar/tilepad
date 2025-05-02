import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:marco_deck/src/client/client_providers.dart';
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
  bool _isReconnecting = false;
  String? _lastConnectedAddress;
  Timer? _reconnectTimer;
  void Function(bool)? _onReconnectionStateChanged;

  // Connection monitoring
  StreamController<ConnectionStatus>? _connectionStatusController;
  Timer? _connectionMonitorTimer;

  @override
  WebSocketChannel? get channel => _channel;

  @override
  bool get isConnected => _isConnected;

  @override
  bool get isReconnecting => _isReconnecting;

  @override
  set onReconnectionStateChanged(void Function(bool) callback) {
    _onReconnectionStateChanged = callback;
  }

  @override
  Stream<ConnectionStatus> get connectionStatusStream {
    _connectionStatusController ??=
        StreamController<ConnectionStatus>.broadcast();
    return _connectionStatusController!.stream;
  }

  @override
  void cancelReconnection() {
    if (_isReconnecting) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _isReconnecting = false;
      if (_onReconnectionStateChanged != null) {
        _onReconnectionStateChanged!(false);
      }
    }
  }

  @override
  Stream<Message> get messageStream => _messageController.stream;

  @override
  Future<bool> connect(String address) async {
    try {
      debugPrint('Web: Attempting to connect to: $address');
      _lastConnectedAddress = address;

      // Close existing connection if any
      await close();

      // Create a web socket connection with timeout handling
      try {
        // Create a timeout that will cancel the connection attempt if it takes too long
        final connectionTimeout = Timer(const Duration(seconds: 8), () {
          debugPrint('Web: Connection attempt timed out');
          // If we're still trying to connect when this timer fires, close the connection
          if (_channel != null && !_isConnected) {
            _channel?.sink.close();
            _channel = null;
          }
        });

        _channel = HtmlWebSocketChannel.connect(address);

        // Wait a very short time to see if we get an immediate error
        await Future.delayed(const Duration(milliseconds: 100));

        // Cancel timeout if we get here without an exception
        connectionTimeout.cancel();
      } catch (e) {
        debugPrint('Web: Immediate connection failure: $e');
        _isConnected = false;
        _startReconnectionTimer();
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
              debugPrint('Web: Error decoding message: $e');
            }
          }
        },
        onDone: () {
          debugPrint('Web: WebSocket connection closed');
          _isConnected = false;

          // Notify about disconnection
          if (_connectionStatusController != null) {
            _connectionStatusController!.add(ConnectionStatus.disconnected);
          }

          _startReconnectionTimer();
        },
        onError: (error) {
          debugPrint('Web: WebSocket error: $error');
          _isConnected = false;

          // Notify about disconnection
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
          debugPrint('Web: Connection was closed during initial delay');
          _isConnected = false;
          _startReconnectionTimer();
          return false;
        }

        // Send a test ping to verify the connection is actually working
        try {
          debugPrint('Web: Sending test ping to verify connection');
          _channel!.sink.add(
            Message(
              type: MessageType.ping,
              payload: {'timestamp': DateTime.now().millisecondsSinceEpoch},
            ).encode(),
          );
        } catch (e) {
          debugPrint('Web: Error sending test ping: $e');
          _isConnected = false;
          await _channel?.sink.close();
          _channel = null;
          return false;
        }
      } catch (e) {
        debugPrint('Web: Error during connection verification: $e');
        _isConnected = false;
        _startReconnectionTimer();
        return false;
      }

      _isConnected = true;
      debugPrint('Web: Connection established');

      // If we were reconnecting, notify that we're no longer reconnecting
      if (_isReconnecting) {
        _isReconnecting = false;
        if (_onReconnectionStateChanged != null) {
          _onReconnectionStateChanged!(false);
        }
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
      }

      // Start connection monitoring
      _startConnectionMonitoring();

      return true;
    } catch (e) {
      _isConnected = false;
      debugPrint('Web: Failed to connect: $e');
      _startReconnectionTimer();
      return false;
    }
  }

  void _startReconnectionTimer() {
    if (_isReconnecting || _lastConnectedAddress == null) return;

    _isReconnecting = true;
    // Notify about reconnection state change
    if (_onReconnectionStateChanged != null) {
      _onReconnectionStateChanged!(true);
    }

    // Track reconnection attempts for exponential backoff
    int currentReconnectAttempt = 0;
    final int maxReconnectAttempts = 10;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!_isReconnecting) {
        timer.cancel();
        return;
      }

      currentReconnectAttempt++;

      // Calculate delay based on attempt number (exponential backoff with a cap)
      // This will start at 5 seconds and gradually increase
      final int delaySeconds =
          currentReconnectAttempt > 5
              ? 20 // Cap at 20 seconds max delay
              : 5 * currentReconnectAttempt;

      debugPrint(
        'Web: Reconnection attempt $currentReconnectAttempt of $maxReconnectAttempts (delay: ${delaySeconds}s)',
      );

      // Notify status update via reconnection state change
      if (_onReconnectionStateChanged != null) {
        _onReconnectionStateChanged!(true);
      }

      if (_connectionStatusController != null) {
        _connectionStatusController!.add(ConnectionStatus.reconnecting);
      }

      try {
        final success = await connect(_lastConnectedAddress!);
        if (success) {
          debugPrint('Web: Reconnection successful');
          timer.cancel();
          _isReconnecting = false;
          if (_onReconnectionStateChanged != null) {
            _onReconnectionStateChanged!(false);
          }
        } else {
          // Don't attempt to reconnect again immediately
          // The timer will trigger the next attempt after the specified delay
          debugPrint(
            'Web: Reconnection attempt failed, waiting ${delaySeconds}s before next attempt',
          );

          // If we've reached the maximum number of attempts, stop reconnecting
          if (currentReconnectAttempt >= maxReconnectAttempts) {
            debugPrint('Web: Maximum reconnection attempts reached, giving up');
            timer.cancel();
            _isReconnecting = false;
            if (_onReconnectionStateChanged != null) {
              _onReconnectionStateChanged!(false);
            }
          }
        }
      } catch (e) {
        debugPrint('Web: Reconnection attempt failed: $e');
        // Don't attempt to reconnect again immediately
        // Let the timer handle the next attempt after delay
      }
    });
  }

  @override
  void sendMessage(Message message) {
    if (_channel != null && _isConnected) {
      try {
        _channel!.sink.add(message.encode());
      } catch (e) {
        debugPrint('Web: Error sending message: $e');
        _isConnected = false;
        _startReconnectionTimer();
      }
    }
  }

  @override
  Future<void> close() async {
    debugPrint('Web: Closing WebSocket connection and cleaning up resources');
    _isConnected = false;

    // Cancel reconnection
    cancelReconnection();

    // Stop connection monitoring
    _stopConnectionMonitoring();

    // Close the channel properly
    try {
      await _channel?.sink.close(1000, 'Connection closed by client');
    } catch (e) {
      debugPrint('Web: Error closing WebSocket channel: $e');
    } finally {
      _channel = null;
      _lastConnectedAddress = null; // Reset the address to ensure a clean state
    }
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
