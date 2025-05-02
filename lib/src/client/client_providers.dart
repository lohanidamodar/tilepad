import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/button.dart';
import '../models/message.dart';
import '../models/server_connection.dart';
import '../network/websocket_service.dart';

/// Provider for the list of saved server connections
final serverConnectionsProvider =
    StateNotifierProvider<ServerConnectionsNotifier, List<ServerConnection>>((
      ref,
    ) {
      return ServerConnectionsNotifier(ref);
    });

/// Provider for the default server ID
final defaultServerIdProvider = StateProvider<String?>((ref) {
  // The initial value will be updated by ServerConnectionsNotifier when it loads
  return null;
});

/// Provider for the currently selected server connection
final selectedServerConnectionProvider = StateProvider<ServerConnection?>(
  (ref) => null,
);

/// Provider for the connection state
final connectionStateProvider =
    StateNotifierProvider<ConnectionStateNotifier, ConnectionState>((ref) {
      return ConnectionStateNotifier(ref);
    });

/// Provider for pages from the server
final pagesProvider = StateProvider<List<Page>>((ref) {
  return [];
});

/// Provider for the currently selected page index
final selectedPageIndexProvider = StateProvider<int>((ref) {
  return 0;
});

/// Provider for the buttons from the server (for backward compatibility)
final buttonsProvider = StateProvider<List<Button>>((ref) {
  // Get all buttons from all pages
  final pages = ref.watch(pagesProvider);
  final allButtons = <Button>[];
  for (final page in pages) {
    allButtons.addAll(page.buttons);
  }
  return allButtons;
});

/// Provider for command results
final commandResultProvider = StateProvider<CommandResultEvent?>((ref) {
  return null;
});

/// Provider for the keep screen awake setting
final keepAwakeProvider = StateNotifierProvider<KeepAwakeNotifier, bool>((ref) {
  return KeepAwakeNotifier();
});

/// Notifier for the keep screen awake setting
class KeepAwakeNotifier extends StateNotifier<bool> {
  /// Creates a new keep awake notifier
  KeepAwakeNotifier() : super(true) {
    _loadPreference();
  }

  /// Loads the saved preference
  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keepAwake = prefs.getBool('keep_screen_awake') ?? true;
      state = keepAwake;

      // Apply the setting
      if (keepAwake) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }
    } catch (e) {
      debugPrint('Error loading keep awake preference: $e');
    }
  }

  /// Sets whether to keep the screen awake
  Future<void> setKeepAwake(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('keep_screen_awake', value);
      state = value;

      // Apply the setting
      if (value) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }
    } catch (e) {
      debugPrint('Error saving keep awake preference: $e');
    }
  }
}

/// Notifier for server connections
class ServerConnectionsNotifier extends StateNotifier<List<ServerConnection>> {
  final Ref? _ref;
  String? _defaultServerId;

  /// Get the default server ID, if any
  String? get defaultServerId => _defaultServerId;

  /// Get the default server connection, if set
  ServerConnection? get defaultServer {
    if (_defaultServerId == null) return null;

    try {
      return state.firstWhere((c) => c.id == _defaultServerId);
    } catch (_) {
      return null;
    }
  }

  /// Creates a new server connections notifier
  ServerConnectionsNotifier([this._ref]) : super([]) {
    _loadConnections();
  }

  /// Loads the saved connections from preferences
  Future<void> _loadConnections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final connectionsJson = prefs.getStringList('server_connections') ?? [];
      _defaultServerId = prefs.getString('default_server_id');

      // Update the default server ID provider if ref is available
      if (_ref != null) {
        _ref.read(defaultServerIdProvider.notifier).state = _defaultServerId;
      }

      final connections =
          connectionsJson
              .map((json) => ServerConnection.fromJson(jsonDecode(json)))
              .toList();

      // Sort by last connected
      connections.sort((a, b) => b.lastConnected.compareTo(a.lastConnected));

      state = connections;
    } catch (e) {
      debugPrint('Error loading server connections: $e');
    }
  }

  /// Saves the connections to preferences
  Future<void> _saveConnections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final connectionsJson =
          state.map((connection) => jsonEncode(connection.toJson())).toList();

      await prefs.setStringList('server_connections', connectionsJson);

      // Save default server ID
      if (_defaultServerId != null) {
        await prefs.setString('default_server_id', _defaultServerId!);
      } else {
        await prefs.remove('default_server_id');
      }
    } catch (e) {
      debugPrint('Error saving server connections: $e');
    }
  }

  /// Sets or clears the default server
  Future<void> setDefaultServer(String? serverId) async {
    _defaultServerId = serverId;

    // Update the default server ID provider if ref is available
    if (_ref != null) {
      _ref.read(defaultServerIdProvider.notifier).state = _defaultServerId;
    }

    await _saveConnections();
  }

  /// Adds a new server connection
  void addConnection(ServerConnection connection) {
    // Check if connection with same address already exists
    final existingIndex = state.indexWhere(
      (c) => c.address == connection.address,
    );

    if (existingIndex >= 0) {
      // Update existing connection
      final updated = state[existingIndex].copyWith(
        name: connection.name,
        lastConnected: DateTime.now(),
      );

      state = [
        ...state.sublist(0, existingIndex),
        updated,
        ...state.sublist(existingIndex + 1),
      ];
    } else {
      // Add new connection
      state = [connection, ...state];
    }

    _saveConnections();
  }

  /// Updates a server connection
  void updateConnection(ServerConnection connection) {
    final index = state.indexWhere((c) => c.id == connection.id);

    if (index >= 0) {
      state = [
        ...state.sublist(0, index),
        connection,
        ...state.sublist(index + 1),
      ];

      _saveConnections();
    }
  }

  /// Removes a server connection
  void removeConnection(String id) {
    state = state.where((connection) => connection.id != id).toList();
    _saveConnections();
  }

  /// Updates the last connected time for a server
  void updateLastConnected(String id) {
    final index = state.indexWhere((c) => c.id == id);

    if (index >= 0) {
      final updated = state[index].copyWith(lastConnected: DateTime.now());

      state = [
        ...state.sublist(0, index),
        updated,
        ...state.sublist(index + 1),
      ];

      _saveConnections();
    }
  }
}

/// Connection state enum
enum ConnectionStatus {
  /// Not connected to any server
  disconnected,

  /// Attempting to connect to a server
  connecting,

  /// Attempting to reconnect to a server after connection loss
  reconnecting,

  /// Connected to a server
  connected,

  /// Error occurred during connection
  error,
}

/// Connection state class
class ConnectionState {
  /// Current connection status
  final ConnectionStatus status;

  /// Error message if applicable
  final String? errorMessage;

  /// Current server connection if connected
  final ServerConnection? connection;

  /// Creates a new connection state
  const ConnectionState({
    required this.status,
    this.errorMessage,
    this.connection,
  });

  /// Creates a copy of this connection state with the specified fields replaced
  ConnectionState copyWith({
    ConnectionStatus? status,
    String? errorMessage,
    ServerConnection? connection,
  }) {
    return ConnectionState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      connection: connection ?? this.connection,
    );
  }
}

/// Notifier for connection state
class ConnectionStateNotifier extends StateNotifier<ConnectionState> {
  final Ref _ref;
  final ClientWebSocketService _webSocketService = ClientWebSocketService();
  late StreamSubscription<Message> _messageSubscription;
  Timer? _connectionTimeoutTimer;

  // Reconnection tracking
  bool _isReconnecting = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  /// Gets whether the service is currently attempting to reconnect
  bool get isReconnecting => _isReconnecting;

  /// Sets up listener for WebSocket reconnection
  void _setupReconnectionListener() {
    // Listen for the reconnection state from the WebSocket service
    // We'll use a stream transformer to listen to changes in the connection status
    _webSocketService.onReconnectionStateChanged = (isReconnecting) {
      if (isReconnecting && state.status != ConnectionStatus.reconnecting) {
        // Only update if we're not already in reconnecting state
        if (state.connection != null) {
          state = ConnectionState(
            status: ConnectionStatus.reconnecting,
            connection: state.connection,
            errorMessage: 'Connection lost, attempting to reconnect...',
          );
        }
        _isReconnecting = true;
        _startReconnectAttemptCounter();
      } else if (!isReconnecting && _isReconnecting) {
        _isReconnecting = false;
        _cancelReconnectAttemptCounter();
      }
    };
  }

  /// Creates a new connection state notifier
  ConnectionStateNotifier(this._ref)
    : super(const ConnectionState(status: ConnectionStatus.disconnected)) {
    // Listen for server messages
    _messageSubscription = _webSocketService.messageStream.listen(
      _handleServerMessage,
    );

    // Set up reconnection listener
    _setupReconnectionListener();
  }

  @override
  void dispose() {
    _cancelConnectionTimeout();
    _messageSubscription.cancel();
    _webSocketService.close();
    super.dispose();
  }

  /// Connects to a server
  Future<bool> connect(ServerConnection connection) async {
    try {
      debugPrint('Connecting to server: ${connection.address}');
      // If currently reconnecting, cancel that first
      if (_isReconnecting) {
        cancelReconnection();
      }

      // Update state to connecting
      state = ConnectionState(
        status: ConnectionStatus.connecting,
        connection: connection,
      );

      // Close existing connection if connected
      if (_webSocketService.isConnected) {
        await disconnect();
      }

      // Set a connection timeout
      _setConnectionTimeout();

      // Attempt to connect
      final success = await _webSocketService.connect(connection.address);

      // Cancel the timeout timer
      _cancelConnectionTimeout();

      if (success) {
        // Send connect message
        _webSocketService.sendMessage(Message(type: MessageType.connect));

        // Update the last connected time
        _ref
            .read(serverConnectionsProvider.notifier)
            .updateLastConnected(connection.id);

        // We don't set connected state here - we wait for the connectAck message
        // But we should set a timeout for the acknowledgment
        _setAckTimeout(connection);

        return true;
      } else {
        // If the connect call returned false, update state to error immediately
        state = ConnectionState(
          status: ConnectionStatus.error,
          errorMessage: 'Failed to connect to server',
          connection: connection,
        );

        return false;
      }
    } catch (e) {
      // Cancel the timeout timer
      _cancelConnectionTimeout();

      debugPrint('Error connecting to server: $e');

      // Update state to error
      state = ConnectionState(
        status: ConnectionStatus.error,
        errorMessage: 'Error: $e',
        connection: connection,
      );

      return false;
    }
  }

  /// Sets a timeout for waiting for the server to acknowledge the connection
  Timer? _ackTimeoutTimer;

  void _setAckTimeout(ServerConnection connection) {
    _cancelAckTimeout();

    // Set a timeout for receiving the connection acknowledgment
    _ackTimeoutTimer = Timer(const Duration(seconds: 5), () {
      if (state.status == ConnectionStatus.connecting) {
        // We didn't receive an acknowledgment within timeout period
        _webSocketService.close();

        state = ConnectionState(
          status: ConnectionStatus.error,
          errorMessage: 'Server did not respond',
          connection: connection,
        );
      }
    });
  }

  void _cancelAckTimeout() {
    _ackTimeoutTimer?.cancel();
    _ackTimeoutTimer = null;
  }

  /// Sets a timeout for connection attempts
  void _setConnectionTimeout() {
    // Cancel any existing timeout
    _cancelConnectionTimeout();

    // Set a new timeout (10 seconds)
    _connectionTimeoutTimer = Timer(const Duration(seconds: 10), () {
      if (state.status == ConnectionStatus.connecting) {
        // Connection attempt has timed out
        _webSocketService.close();

        if (state.connection != null) {
          // Instead of just showing an error, transition to reconnecting state
          state = ConnectionState(
            status: ConnectionStatus.reconnecting,
            errorMessage: 'Connection timed out, attempting to reconnect...',
            connection: state.connection,
          );

          // Start reconnection process
          _handleConnectionTimeout();
        } else {
          // If no connection info, just show error
          state = ConnectionState(
            status: ConnectionStatus.error,
            errorMessage: 'Connection timed out',
            connection: state.connection,
          );
        }
      }
    });
  }

  /// Handles connection timeout by initiating auto-retry
  void _handleConnectionTimeout() {
    if (state.connection == null) return;

    // Start reconnect attempt counter and retry connection
    _isReconnecting = true;
    _startReconnectAttemptCounter();

    // Schedule first retry after a short delay
    Timer(const Duration(milliseconds: 500), () {
      if (_isReconnecting && state.connection != null) {
        _retryConnection();
      }
    });
  }

  /// Retries connection after timeout or other error
  Future<void> _retryConnection() async {
    if (!_isReconnecting || state.connection == null) return;

    try {
      debugPrint('Auto-retrying connection after timeout...');
      final success = await _webSocketService.connect(
        state.connection!.address,
      );

      if (success) {
        // Send connect message
        _webSocketService.sendMessage(Message(type: MessageType.connect));

        // Set ack timeout
        _setAckTimeout(state.connection!);
      } else {
        // Let the reconnection timer handle the next retry
        debugPrint('Auto-retry failed, will try again...');
      }
    } catch (e) {
      debugPrint('Error during auto-retry: $e');
      // Keep reconnection state active, timer will handle next retry
    }
  }

  /// Cancels the connection timeout timer if it exists
  void _cancelConnectionTimeout() {
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = null;
  }

  /// Cancels an ongoing connection attempt
  void cancelConnection() {
    if (state.status == ConnectionStatus.connecting) {
      _cancelConnectionTimeout();
      _webSocketService.close();
      state = const ConnectionState(status: ConnectionStatus.disconnected);
    }
  }

  /// Disconnects from the server
  Future<void> disconnect() async {
    debugPrint('Fully disconnecting from server and cleaning up resources');

    // Cancel all timers and pending operations
    _cancelConnectionTimeout();
    _cancelAckTimeout();
    _cancelReconnectAttemptCounter();

    // Make sure any reconnection attempts are canceled
    if (_isReconnecting) {
      _webSocketService.cancelReconnection();
      _isReconnecting = false;
    }

    // Close the WebSocket connection properly
    await _webSocketService.close();

    // Completely reset the state
    state = const ConnectionState(status: ConnectionStatus.disconnected);

    // Clear buttons
    _ref.read(pagesProvider.notifier).state = [];
    _ref.read(selectedPageIndexProvider.notifier).state = 0;
  }

  /// Resets error state back to disconnected
  void resetErrorState() {
    if (state.status == ConnectionStatus.error) {
      state = const ConnectionState(status: ConnectionStatus.disconnected);
    }
  }

  /// Refreshes the current connection
  Future<bool> refreshConnection() async {
    if (state.connection != null) {
      return connect(state.connection!);
    }
    return false;
  }

  /// Presses a button
  void pressButton(String buttonId) {
    if (state.status == ConnectionStatus.connected) {
      _webSocketService.sendMessage(
        Message(type: MessageType.buttonPress, payload: {'buttonId': buttonId}),
      );
    }
  }

  /// Requests the available buttons from the server
  void requestButtons() {
    if (state.status == ConnectionStatus.connected) {
      _webSocketService.sendMessage(Message(type: MessageType.getButtons));
    }
  }

  /// Handles a message from the server
  void _handleServerMessage(Message message) {
    debugPrint('Received message: ${message.type}');

    switch (message.type) {
      case MessageType.connectAck:
        // Update state to connected
        state = state.copyWith(status: ConnectionStatus.connected);
        break;

      case MessageType.buttonsResponse:
        _handleButtonsResponse(message.payload);
        break;

      case MessageType.pagesResponse:
        _handlePagesResponse(message.payload);
        break;

      case MessageType.commandResult:
        _handleCommandResult(message.payload);
        break;

      case MessageType.error:
        debugPrint('Error from server: ${message.payload['error']}');
        break;

      default:
        // Unknown message type
        break;
    }
  }

  /// Handles a buttons response message (for backward compatibility)
  void _handleButtonsResponse(dynamic payload) {
    try {
      final List<dynamic> buttonsJson = payload;
      final buttons = buttonsJson.map((json) => Button.fromJson(json)).toList();

      // Create a single page with these buttons
      final page = Page(name: 'All Buttons', buttons: buttons);

      _ref.read(pagesProvider.notifier).state = [page];
      _ref.read(selectedPageIndexProvider.notifier).state = 0;
    } catch (e) {
      debugPrint('Error handling buttons response: $e');
    }
  }

  /// Handles a pages response message
  void _handlePagesResponse(dynamic payload) {
    try {
      final List<dynamic> pagesJson = payload;
      final List<Page> pages =
          pagesJson.map((json) => Page.fromJson(json)).toList();

      // Sort pages by their order property
      pages.sort((a, b) => a.order.compareTo(b.order));

      _ref.read(pagesProvider.notifier).state = pages;

      // Preserve selected page index if possible, otherwise reset to 0
      final currentIndex = _ref.read(selectedPageIndexProvider);
      if (currentIndex >= pages.length) {
        _ref.read(selectedPageIndexProvider.notifier).state = 0;
      }
    } catch (e) {
      debugPrint('Error handling pages response: $e');
    }
  }

  /// Handles a command result message
  void _handleCommandResult(dynamic payload) {
    try {
      _ref.read(commandResultProvider.notifier).state = CommandResultEvent(
        buttonId: payload['buttonId'],
        success: payload['success'],
        output: payload['output'],
        error: payload['error'],
      );
    } catch (e) {
      debugPrint('Error handling command result: $e');
    }
  }

  /// Starts the reconnect attempt counter
  void _startReconnectAttemptCounter() {
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _reconnectAttempts++;

      // If we've reached max attempts, cancel reconnection
      if (_reconnectAttempts >= _maxReconnectAttempts) {
        cancelReconnection();

        // Set to error state with message
        state = ConnectionState(
          status: ConnectionStatus.error,
          errorMessage:
              'Reconnection failed after $_maxReconnectAttempts attempts',
          connection: state.connection,
        );
      } else {
        // Update the error message to show attempt count
        if (state.status == ConnectionStatus.reconnecting &&
            state.connection != null) {
          state = ConnectionState(
            status: ConnectionStatus.reconnecting,
            connection: state.connection,
            errorMessage:
                'Connection lost, reconnection attempt $_reconnectAttempts of $_maxReconnectAttempts...',
          );
        }
      }
    });
  }

  /// Cancels the reconnect attempt counter
  void _cancelReconnectAttemptCounter() {
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Cancels any ongoing reconnection attempts
  void cancelReconnection() {
    if (_isReconnecting) {
      _webSocketService.cancelReconnection();
      _cancelReconnectAttemptCounter();
      _isReconnecting = false;

      // Update UI to disconnected state
      state = const ConnectionState(status: ConnectionStatus.disconnected);
    }
  }
}

/// Event class for command results
class CommandResultEvent {
  /// The ID of the button that was pressed
  final String buttonId;

  /// Whether the command was successful
  final bool success;

  /// Standard output of the command
  final String output;

  /// Standard error of the command
  final String error;

  /// Creates a new command result event
  CommandResultEvent({
    required this.buttonId,
    required this.success,
    required this.output,
    required this.error,
  });
}
