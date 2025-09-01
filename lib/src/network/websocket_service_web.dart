import 'dart:async';
import 'dart:math';
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

/// Enhanced web implementation of the client WebSocket service
class WebClientWebSocketService implements ClientWebSocketService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<Message>.broadcast();
  bool _isConnected = false;
  bool _isReconnecting = false;
  String? _lastConnectedAddress;
  Timer? _reconnectTimer;
  Timer? _healthCheckTimer;
  void Function(bool)? _onReconnectionStateChanged;

  // Enhanced connection monitoring
  StreamController<ConnectionStatus>? _connectionStatusController;
  int _reconnectAttempts = 0;
  int _maxReconnectAttempts = 15;
  DateTime? _lastPingTime;
  DateTime? _lastPongTime;
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

  @override
  Future<bool> connect(String address) async {
    try {
      debugPrint('Web: Attempting to connect to: $address');
      _lastConnectedAddress = address;
      _reconnectAttempts = 0;

      // Notify connecting status
      if (_connectionStatusController != null) {
        _connectionStatusController!.add(ConnectionStatus.connecting);
      }

      // Close existing connection if any
      await close();

      // Create the WebSocket connection for web
      try {
        _channel = HtmlWebSocketChannel.connect(Uri.parse(address));
      } catch (e) {
        debugPrint('Web: Immediate connection failure: $e');
        _isConnected = false;
        
        if (_connectionStatusController != null) {
          _connectionStatusController!.add(ConnectionStatus.error);
        }
        
        return false;
      }

      // Set up enhanced message handling
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
                  _lastPongTime = DateTime.now();
                  _awaitingPong = false;
                  debugPrint('Web: Received pong - connection healthy');
                  break;
                default:
                  // Forward other messages
                  _messageController.add(message);
                  break;
              }
            } catch (e) {
              debugPrint('Web: Error decoding message: $e');
            }
          }
        },
        onDone: () {
          debugPrint('Web: WebSocket connection closed gracefully');
          _handleDisconnection();
        },
        onError: (error) {
          debugPrint('Web: WebSocket error: $error');
          _handleDisconnection();
        },
      );

      // Enhanced connection verification with timeout
      final connectionSuccess = await _verifyConnection();
      
      if (connectionSuccess) {
        _isConnected = true;
        _reconnectAttempts = 0;
        debugPrint('Web: Connection established successfully');

        // Reset reconnection state
        if (_isReconnecting) {
          _isReconnecting = false;
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
      debugPrint('Web: Failed to connect: $e');
      
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
        debugPrint('Web: Channel closed during verification');
        return false;
      }

      // Send verification ping with timeout
      final verificationCompleter = Completer<bool>();
      Timer? verificationTimeout;
      
      // Set up timeout
      verificationTimeout = Timer(const Duration(seconds: 5), () {
        if (!verificationCompleter.isCompleted) {
          verificationCompleter.complete(false);
        }
      });

      // Listen for pong response
      late StreamSubscription messageSubscription;
      messageSubscription = _messageController.stream.listen((message) {
        if (message.type == MessageType.pong && !verificationCompleter.isCompleted) {
          verificationTimeout?.cancel();
          messageSubscription.cancel();
          verificationCompleter.complete(true);
        }
      });

      // Send verification ping
      try {
        debugPrint('Web: Sending verification ping');
        _sendPing();
        
        final success = await verificationCompleter.future;
        
        verificationTimeout?.cancel();
        messageSubscription.cancel();
        
        if (success) {
          debugPrint('Web: Connection verification successful');
        } else {
          debugPrint('Web: Connection verification failed - timeout');
        }
        
        return success;
      } catch (e) {
        debugPrint('Web: Error during verification ping: $e');
        verificationTimeout?.cancel();
        messageSubscription.cancel();
        return false;
      }
    } catch (e) {
      debugPrint('Web: Error during connection verification: $e');
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
    if (_lastConnectedAddress != null && !_isReconnecting) {
      _startEnhancedReconnection();
    }
  }

  /// Enhanced reconnection with adaptive backoff
  void _startEnhancedReconnection() {
    if (_isReconnecting || _lastConnectedAddress == null) return;

    _isReconnecting = true;
    
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
    if (!_isReconnecting || _reconnectAttempts >= _maxReconnectAttempts) {
      if (_reconnectAttempts >= _maxReconnectAttempts) {
        debugPrint('Web: Maximum reconnection attempts reached');
        _isReconnecting = false;
        
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
      'Web: Scheduling reconnection attempt ${_reconnectAttempts + 1}/$_maxReconnectAttempts in ${delay}ms',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delay), () async {
      if (!_isReconnecting) return;

      _reconnectAttempts++;
      
      debugPrint(
        'Web: Attempting reconnection ${_reconnectAttempts}/$_maxReconnectAttempts to $_lastConnectedAddress',
      );

      final success = await connect(_lastConnectedAddress!);
      
      if (!success && _isReconnecting) {
        // Schedule next attempt
        _scheduleReconnection();
      }
    });
  }

  /// Calculate adaptive reconnection delay
  int _calculateReconnectDelay(int attemptNumber) {
    // Exponential backoff with jitter
    final baseDelay = _baseReconnectDelay * pow(_backoffMultiplier, attemptNumber);
    final cappedDelay = min(baseDelay, _maxReconnectDelay.toDouble()).toInt();
    
    // Add jitter (±25%)
    final jitter = (cappedDelay * 0.25 * (Random().nextDouble() * 2 - 1)).toInt();
    
    return cappedDelay + jitter;
  }

  /// Start health check monitoring
  void _startHealthCheck() {
    _stopHealthCheck();
    
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
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
        if (timeSinceLastPing.inSeconds > 30) {
          debugPrint('Web: Health check failed - no pong received for 30 seconds');
          _handleDisconnection();
          return;
        }
      }

      // Send ping if not awaiting pong
      if (!_awaitingPong) {
        _sendPing();
      }
    } catch (e) {
      debugPrint('Web: Error during health check: $e');
      _handleDisconnection();
    }
  }

  /// Send ping message
  void _sendPing() {
    try {
      _lastPingTime = DateTime.now();
      _awaitingPong = true;
      
      sendMessage(Message(
        type: MessageType.ping,
        payload: {'timestamp': DateTime.now().millisecondsSinceEpoch},
      ));
    } catch (e) {
      debugPrint('Web: Error sending ping: $e');
      _handleDisconnection();
    }
  }

  /// Send pong message
  void _sendPong() {
    try {
      sendMessage(Message(
        type: MessageType.pong,
        payload: {'timestamp': DateTime.now().millisecondsSinceEpoch},
      ));
    } catch (e) {
      debugPrint('Web: Error sending pong: $e');
    }
  }

  @override
  void sendMessage(Message message) {
    if (_channel != null && _isConnected) {
      try {
        _channel!.sink.add(message.encode());
      } catch (e) {
        debugPrint('Web: Error sending message: $e');
        _handleDisconnection();
      }
    } else {
      debugPrint('Web: Cannot send message - not connected');
    }
  }

  @override
  Future<void> close() async {
    _stopHealthCheck();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _isReconnecting = false;
    
    if (_channel != null) {
      try {
        await _channel!.sink.close();
      } catch (e) {
        debugPrint('Web: Error closing channel: $e');
      }
      _channel = null;
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

/// Stub implementation for web server (servers can't run on web)
class WebServerWebSocketService implements ServerWebSocketService {
  @override
  Stream<Message> get messageStream => const Stream.empty();

  @override
  Stream<ClientConnectionEvent> get clientConnectionStream => const Stream.empty();

  @override
  List<ClientInfo> get connectedClients => [];

  @override
  Future<bool> start(int port) async {
    debugPrint('Web: Server cannot be started on web platform');
    return false;
  }

  @override
  void sendMessage(Message message) {
    debugPrint('Web: Cannot send message - server not supported on web');
  }

  @override
  void broadcast(Message message) {
    debugPrint('Web: Cannot broadcast - server not supported on web');
  }

  @override
  Future<void> close() async {
    // Nothing to close on web server stub
  }
}