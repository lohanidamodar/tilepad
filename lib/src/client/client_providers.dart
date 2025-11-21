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
import '../network/discovery_service.dart';
import '../network/discovery_service_stub.dart';

/// Provider for the list of saved server connections
final serverConnectionsProvider =
    NotifierProvider<ServerConnectionsNotifier, List<ServerConnection>>(
      ServerConnectionsNotifier.new,
    );

/// Provider for the default server ID
final defaultServerIdProvider =
    NotifierProvider<DefaultServerIdNotifier, String?>(
      DefaultServerIdNotifier.new,
    );

/// Notifier for the default server ID
class DefaultServerIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) => state = value;
}

/// Provider for the currently selected server connection
final selectedServerConnectionProvider =
    NotifierProvider<SelectedServerConnectionNotifier, ServerConnection?>(
      SelectedServerConnectionNotifier.new,
    );

/// Notifier for the currently selected server connection
class SelectedServerConnectionNotifier extends Notifier<ServerConnection?> {
  @override
  ServerConnection? build() => null;

  void set(ServerConnection? value) => state = value;
}

/// Provider for the connection state
final connectionStateProvider =
    NotifierProvider<ConnectionStateNotifier, ConnectionState>(
      ConnectionStateNotifier.new,
    );

/// Provider for pages from the server
final pagesProvider = NotifierProvider<PagesNotifier, List<Page>>(
  PagesNotifier.new,
);

/// Notifier for pages
class PagesNotifier extends Notifier<List<Page>> {
  @override
  List<Page> build() => [];

  void set(List<Page> value) => state = value;
}

/// Provider for the currently selected page index
final selectedPageIndexProvider =
    NotifierProvider<SelectedPageIndexNotifier, int>(
      SelectedPageIndexNotifier.new,
    );

/// Notifier for selected page index
class SelectedPageIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int value) => state = value;
}

/// Provider for the buttons from the server (for backward compatibility)
final buttonsProvider = Provider<List<Button>>((ref) {
  // Get all buttons from all pages
  final pages = ref.watch(pagesProvider);
  final allButtons = <Button>[];
  for (final page in pages) {
    allButtons.addAll(page.buttons);
  }
  return allButtons;
});

/// Provider for command results
final commandResultProvider =
    NotifierProvider<CommandResultNotifier, CommandResultEvent?>(
      CommandResultNotifier.new,
    );

/// Notifier for command results
class CommandResultNotifier extends Notifier<CommandResultEvent?> {
  @override
  CommandResultEvent? build() => null;

  void set(CommandResultEvent? value) => state = value;
}

/// Provider for the keep screen awake setting
final keepAwakeProvider = NotifierProvider<KeepAwakeNotifier, bool>(
  KeepAwakeNotifier.new,
);

/// Provider for discovered servers via UDP
final discoveredServersProvider =
    NotifierProvider<DiscoveredServersNotifier, List<DiscoveredServer>>(
      DiscoveredServersNotifier.new,
    );

/// Notifier for discovered servers
class DiscoveredServersNotifier extends Notifier<List<DiscoveredServer>> {
  DiscoveryService? _discoveryService;
  StreamSubscription<DiscoveredServer>? _subscription;

  @override
  List<DiscoveredServer> build() {
    ref.onDispose(() {
      _subscription?.cancel();
      _discoveryService?.dispose();
    });
    return [];
  }

  /// Start discovering servers
  Future<void> startDiscovery() async {
    try {
      _discoveryService = createDiscoveryService();

      // Listen for discovered servers
      _subscription = _discoveryService!.discoveredServers.listen((server) {
        final current = [...state];
        // Add or update server in the list
        final index = current.indexWhere(
          (s) => s.ipAddress == server.ipAddress && s.port == server.port,
        );
        if (index >= 0) {
          current[index] = server;
        } else {
          current.add(server);
        }
        state = current;
      });

      await _discoveryService!.startDiscovery();
      debugPrint('Started UDP server discovery');
    } catch (e) {
      debugPrint('Error starting discovery: $e');
    }
  }

  /// Stop discovering servers
  Future<void> stopDiscovery() async {
    try {
      await _subscription?.cancel();
      _subscription = null;
      await _discoveryService?.stopDiscovery();
      state = [];
      debugPrint('Stopped UDP server discovery');
    } catch (e) {
      debugPrint('Error stopping discovery: $e');
    }
  }

  /// Clear discovered servers list
  void clear() {
    state = [];
  }
}

/// Notifier for the keep screen awake setting
class KeepAwakeNotifier extends Notifier<bool> {
  @override
  bool build() {
    _loadPreference();
    return true;
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
class ServerConnectionsNotifier extends Notifier<List<ServerConnection>> {
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

  @override
  List<ServerConnection> build() {
    _initialize();
    return [];
  }

  /// Initializes the notifier and loads connections
  Future<void> _initialize() async {
    await _loadConnections();
  }

  /// Loads the saved connections from preferences
  Future<void> _loadConnections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final connectionsJson = prefs.getStringList('server_connections') ?? [];
      _defaultServerId = prefs.getString('default_server_id');

      // Update the default server ID provider
      ref.read(defaultServerIdProvider.notifier).set(_defaultServerId);

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

    // Update the default server ID provider
    ref.read(defaultServerIdProvider.notifier).set(_defaultServerId);

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
class ConnectionStateNotifier extends Notifier<ConnectionState> {
  final ClientWebSocketService _webSocketService = ClientWebSocketService();
  late StreamSubscription<Message> _messageSubscription;
  late StreamSubscription<ConnectionStatus> _connectionStatusSubscription;
  Timer? _connectionTimeoutTimer;

  // Reconnection tracking
  bool _isReconnecting = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  @override
  ConnectionState build() {
    // Listen for server messages
    _messageSubscription = _webSocketService.messageStream.listen(
      _handleServerMessage,
    );

    // Listen for connection status changes from the WebSocket service
    _connectionStatusSubscription = _webSocketService.connectionStatusStream
        .listen(_handleConnectionStatusChange);

    // Set up reconnection listener
    _setupReconnectionListener();

    // Clean up when the provider is disposed
    ref.onDispose(() {
      _cancelConnectionTimeout();
      _messageSubscription.cancel();
      _connectionStatusSubscription.cancel();
      _webSocketService.close();
    });

    return const ConnectionState(status: ConnectionStatus.disconnected);
  }

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

  /// Handle connection status changes from the WebSocket service
  void _handleConnectionStatusChange(ConnectionStatus status) {
    debugPrint('Connection status changed: $status');

    if (status == ConnectionStatus.disconnected &&
        state.status != ConnectionStatus.disconnected &&
        state.status != ConnectionStatus.reconnecting) {
      // If we were connected but now we're disconnected, and not already reconnecting
      debugPrint('Connection lost, updating UI to disconnected state');

      // Check if we have a connection to retry with
      if (state.connection != null) {
        // Update UI to show reconnecting state
        state = ConnectionState(
          status: ConnectionStatus.reconnecting,
          connection: state.connection,
          errorMessage: 'Connection lost, attempting to reconnect...',
        );

        // Start reconnection process
        _isReconnecting = true;
        _startReconnectAttemptCounter();
      } else {
        // Just show disconnected
        state = const ConnectionState(status: ConnectionStatus.disconnected);
      }
    }
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
        ref
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
    ref.read(pagesProvider.notifier).set([]);
    ref.read(selectedPageIndexProvider.notifier).set(0);
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

      ref.read(pagesProvider.notifier).set([page]);
      ref.read(selectedPageIndexProvider.notifier).set(0);
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

      ref.read(pagesProvider.notifier).set(pages);

      // Preserve selected page index if possible, otherwise reset to 0
      final currentIndex = ref.read(selectedPageIndexProvider);
      if (currentIndex >= pages.length) {
        ref.read(selectedPageIndexProvider.notifier).set(0);
      }
    } catch (e) {
      debugPrint('Error handling pages response: $e');
    }
  }

  /// Handles a command result message
  void _handleCommandResult(dynamic payload) {
    try {
      ref
          .read(commandResultProvider.notifier)
          .set(
            CommandResultEvent(
              buttonId: payload['buttonId'],
              success: payload['success'],
              output: payload['output'],
              error: payload['error'],
            ),
          );
    } catch (e) {
      debugPrint('Error handling command result: $e');
    }
  }

  /// Starts the reconnect attempt counter
  void _startReconnectAttemptCounter() {
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _reconnectAttempts++;

      // Only update the UI every 5 seconds or when a new attempt is about to happen
      if (_reconnectAttempts % 5 == 0 || _reconnectAttempts % 5 == 1) {
        // Calculate how long until next reconnection attempt based on the attempt number
        int delayBetweenAttempts =
            _reconnectAttempts > 5 ? 20 : 5 * (_reconnectAttempts ~/ 5 + 1);
        int secondsUntilNextAttempt =
            delayBetweenAttempts - (_reconnectAttempts % delayBetweenAttempts);

        // If we've just made an attempt, report the next delay
        if (_reconnectAttempts % delayBetweenAttempts == 1) {
          secondsUntilNextAttempt = delayBetweenAttempts - 1;
        }

        // Update the error message to show attempt count and time until next attempt
        if (state.status == ConnectionStatus.reconnecting &&
            state.connection != null) {
          // Show the correct attempt number (attempts are counted from 1)
          final int displayAttempt =
              (_reconnectAttempts / delayBetweenAttempts).ceil();

          state = ConnectionState(
            status: ConnectionStatus.reconnecting,
            connection: state.connection,
            errorMessage:
                secondsUntilNextAttempt <= 0
                    ? 'Connection lost, attempting reconnection $displayAttempt of $_maxReconnectAttempts...'
                    : 'Connection lost, next reconnection attempt in ${secondsUntilNextAttempt}s ($displayAttempt of $_maxReconnectAttempts)',
          );
        }
      }

      // If we've reached max attempts, cancel reconnection
      if (_reconnectAttempts >= 120) {
        // ~2 minutes total time (with increasing delays)
        cancelReconnection();

        // Set to error state with message
        state = ConnectionState(
          status: ConnectionStatus.error,
          errorMessage: 'Reconnection failed after multiple attempts',
          connection: state.connection,
        );
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
