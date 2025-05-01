import 'dart:async';
import 'package:flutter/foundation.dart'; // Add Flutter foundation import

import '../models/button.dart';
import '../models/message.dart';
import '../models/client_info.dart';
import '../network/websocket_service.dart';
import 'button_manager.dart';
import 'command_executor.dart';

/// Server class that handles client connections and executes commands
class MarcoServer {
  /// The WebSocket service for client communication
  final ServerWebSocketService _webSocketService = ServerWebSocketService();

  /// The button manager
  final ButtonManager _buttonManager = ButtonManager();

  /// The command executor
  final CommandExecutor _commandExecutor = CommandExecutor();

  /// Stream controller for client connection events
  final _clientsController = StreamController<List<ClientInfo>>.broadcast();

  /// The port to listen on
  final int _port;

  /// Whether the server is running
  bool _isRunning = false;

  /// List of connected clients
  List<ClientInfo> _connectedClients = [];

  /// Creates a new server
  MarcoServer({int port = 8080}) : _port = port;

  /// Gets the server's IP address
  Future<String> getServerIp() async {
    return await _commandExecutor.getServerIpAddress();
  }

  /// Gets the server's port
  int get serverPort => _port;

  /// Gets whether the server is running
  bool get isRunning => _isRunning;

  /// Gets the list of all configured buttons
  List<Button> get buttons => _buttonManager.buttons;

  /// Gets the list of connected clients
  List<ClientInfo> get connectedClients => _connectedClients;

  /// Stream of connected clients updates
  Stream<List<ClientInfo>> get clientsStream => _clientsController.stream;

  /// Starts the server
  Future<bool> start() async {
    try {
      // Initialize button manager
      await _buttonManager.initialize();

      // Start WebSocket server
      final success = await _webSocketService.start(_port);
      if (!success) {
        return false;
      }

      _isRunning = true;

      // Listen for client messages
      _webSocketService.messageStream.listen(_handleClientMessage);

      // Listen for client connections and disconnections
      _webSocketService.clientConnectionStream.listen(_handleClientConnection);

      // Initialize connected clients list
      _updateConnectedClients();

      return true;
    } catch (e) {
      debugPrint('Failed to start server: $e');
      return false;
    }
  }

  /// Updates the connected clients list and notifies listeners
  void _updateConnectedClients() {
    _connectedClients = _webSocketService.connectedClients;
    _clientsController.add(_connectedClients);
  }

  /// Handles client connection and disconnection events
  void _handleClientConnection(ClientConnectionEvent event) {
    debugPrint(
      'Client ${event.connected ? 'connected' : 'disconnected'}: ${event.clientInfo.ipAddress}',
    );

    // Update the connected clients list
    _updateConnectedClients();
  }

  /// Stops the server
  Future<void> stop() async {
    if (_isRunning) {
      await _webSocketService.close();
      _isRunning = false;
      _connectedClients = [];
      _clientsController.add(_connectedClients);
    }
  }

  /// Handles a message from a client
  void _handleClientMessage(Message message) async {
    switch (message.type) {
      case MessageType.connect:
        // Send connect acknowledgment
        _webSocketService.sendMessage(Message(type: MessageType.connectAck));

        // Send buttons to the newly connected client
        _webSocketService.sendMessage(
          Message(
            type: MessageType.buttonsResponse,
            payload: _buttonManager.buttons.map((b) => b.toJson()).toList(),
          ),
        );
        break;

      case MessageType.getButtons:
        // Send list of buttons
        _webSocketService.sendMessage(
          Message(
            type: MessageType.buttonsResponse,
            payload: _buttonManager.buttons.map((b) => b.toJson()).toList(),
          ),
        );
        break;

      case MessageType.buttonPress:
        _handleButtonPress(message.payload);
        break;

      default:
        // Unknown message type
        debugPrint('Unknown message type: ${message.type}');
        break;
    }
  }

  /// Handles a button press message
  void _handleButtonPress(dynamic payload) async {
    if (payload == null || !payload.containsKey('buttonId')) {
      return;
    }

    final buttonId = payload['buttonId'];
    final button = _buttonManager.getButton(buttonId);

    if (button == null) {
      _webSocketService.sendMessage(
        Message(
          type: MessageType.error,
          payload: {'error': 'Button not found'},
        ),
      );
      return;
    }

    try {
      final result = await _commandExecutor.execute(button);
      _webSocketService.sendMessage(
        Message(
          type: MessageType.commandResult,
          payload: {
            'buttonId': buttonId,
            'success': result.success,
            'output': result.output,
            'error': result.error,
          },
        ),
      );
    } catch (e) {
      _webSocketService.sendMessage(
        Message(
          type: MessageType.commandResult,
          payload: {
            'buttonId': buttonId,
            'success': false,
            'output': '',
            'error': 'Error executing command: $e',
          },
        ),
      );
    }
  }

  /// Adds a new button
  void addButton(Button button) {
    _buttonManager.addButton(button);

    // Notify clients of the button change
    _broadcastButtons();
  }

  /// Updates an existing button
  void updateButton(Button button) {
    _buttonManager.updateButton(button);

    // Notify clients of the button change
    _broadcastButtons();
  }

  /// Deletes a button
  void deleteButton(String id) {
    _buttonManager.deleteButton(id);

    // Notify clients of the button change
    _broadcastButtons();
  }

  /// Broadcasts the button list to all connected clients
  void _broadcastButtons() {
    if (_isRunning) {
      _webSocketService.broadcast(
        Message(
          type: MessageType.buttonsResponse,
          payload: _buttonManager.buttons.map((b) => b.toJson()).toList(),
        ),
      );
    }
  }

  /// Disposes the server resources
  void dispose() async {
    await stop();
    await _clientsController.close();
  }
}
