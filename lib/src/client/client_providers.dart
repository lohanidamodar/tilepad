import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/button.dart';
import '../models/message.dart';
import '../models/server_connection.dart';
import '../network/websocket_service.dart';

/// Provider for the list of saved server connections
final serverConnectionsProvider =
    StateNotifierProvider<ServerConnectionsNotifier, List<ServerConnection>>((
      ref,
    ) {
      return ServerConnectionsNotifier();
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

/// Provider for the buttons from the server
final buttonsProvider = StateProvider<List<Button>>((ref) {
  return [];
});

/// Provider for command results
final commandResultProvider = StateProvider<CommandResultEvent?>((ref) {
  return null;
});

/// Notifier for server connections
class ServerConnectionsNotifier extends StateNotifier<List<ServerConnection>> {
  /// Creates a new server connections notifier
  ServerConnectionsNotifier() : super([]) {
    _loadConnections();
  }

  /// Loads the saved connections from preferences
  Future<void> _loadConnections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final connectionsJson = prefs.getStringList('server_connections') ?? [];

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
    } catch (e) {
      debugPrint('Error saving server connections: $e');
    }
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

  /// Creates a new connection state notifier
  ConnectionStateNotifier(this._ref)
    : super(const ConnectionState(status: ConnectionStatus.disconnected)) {
    // Listen for server messages
    _messageSubscription = _webSocketService.messageStream.listen(
      _handleServerMessage,
    );
  }

  @override
  void dispose() {
    _messageSubscription.cancel();
    _webSocketService.close();
    super.dispose();
  }

  /// Connects to a server
  Future<bool> connect(ServerConnection connection) async {
    try {
      // Update state to connecting
      state = ConnectionState(
        status: ConnectionStatus.connecting,
        connection: connection,
      );

      // Close existing connection if connected
      if (state.status == ConnectionStatus.connected) {
        await disconnect();
      }

      final success = await _webSocketService.connect(connection.address);

      if (success) {
        // Send connect message
        _webSocketService.sendMessage(Message(type: MessageType.connect));

        // Update the last connected time
        _ref
            .read(serverConnectionsProvider.notifier)
            .updateLastConnected(connection.id);

        return true;
      } else {
        // Update state to error
        state = ConnectionState(
          status: ConnectionStatus.error,
          errorMessage: 'Failed to connect to server',
        );

        return false;
      }
    } catch (e) {
      debugPrint('Error connecting to server: $e');

      // Update state to error
      state = ConnectionState(
        status: ConnectionStatus.error,
        errorMessage: 'Error: $e',
      );

      return false;
    }
  }

  /// Disconnects from the server
  Future<void> disconnect() async {
    await _webSocketService.close();

    // Update state to disconnected
    state = const ConnectionState(status: ConnectionStatus.disconnected);

    // Clear buttons
    _ref.read(buttonsProvider.notifier).state = [];
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

  /// Handles a buttons response message
  void _handleButtonsResponse(dynamic payload) {
    try {
      final List<dynamic> buttonsJson = payload;
      final buttons = buttonsJson.map((json) => Button.fromJson(json)).toList();
      _ref.read(buttonsProvider.notifier).state = buttons;
    } catch (e) {
      debugPrint('Error handling buttons response: $e');
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
