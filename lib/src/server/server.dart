import 'dart:convert';

import '../models/button.dart';
import '../models/message.dart';
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

  /// The port to listen on
  final int _port;

  /// Whether the server is running
  bool _isRunning = false;

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

      return true;
    } catch (e) {
      print('Failed to start server: $e');
      return false;
    }
  }

  /// Stops the server
  Future<void> stop() async {
    if (_isRunning) {
      await _webSocketService.close();
      _isRunning = false;
    }
  }

  /// Handles a message from a client
  void _handleClientMessage(Message message) async {
    print('Received message: ${message.type}');

    switch (message.type) {
      case MessageType.connect:
        _handleClientConnect();
        break;
      case MessageType.getButtons:
        _handleGetButtons();
        break;
      case MessageType.buttonPress:
        await _handleButtonPress(message.payload);
        break;
      case MessageType.updateButton:
        _handleUpdateButton(message.payload);
        break;
      default:
        // Unknown message type
        break;
    }
  }

  /// Handles a client connect message
  void _handleClientConnect() {
    _webSocketService.sendMessage(
      Message(type: MessageType.connectAck, payload: {'status': 'connected'}),
    );

    // After connecting, send the buttons to the client
    _handleGetButtons();
  }

  /// Handles a get buttons message
  void _handleGetButtons() {
    final buttonsJson = _buttonManager.buttons.map((b) => b.toJson()).toList();
    _webSocketService.sendMessage(
      Message(type: MessageType.buttonsResponse, payload: buttonsJson),
    );
  }

  /// Handles a button press message
  Future<void> _handleButtonPress(dynamic payload) async {
    try {
      final String buttonId = payload['buttonId'];
      final button = _buttonManager.buttons.firstWhere(
        (b) => b.id == buttonId,
        orElse: () => throw Exception('Button not found'),
      );

      print('Executing command: ${button.command}');
      final result = await _commandExecutor.executeCommand(button.command);

      _webSocketService.sendMessage(
        Message(
          type: MessageType.commandResult,
          payload: {'buttonId': buttonId, ...result.toJson()},
        ),
      );
    } catch (e) {
      _webSocketService.sendMessage(
        Message(type: MessageType.error, payload: {'error': e.toString()}),
      );
    }
  }

  /// Handles an update button message
  void _handleUpdateButton(dynamic payload) {
    try {
      final button = Button.fromJson(payload);
      final success = _buttonManager.updateButton(button);

      if (!success) {
        _buttonManager.addButton(button);
      }

      // Send updated buttons list to all clients
      _handleGetButtons();
    } catch (e) {
      _webSocketService.sendMessage(
        Message(type: MessageType.error, payload: {'error': e.toString()}),
      );
    }
  }

  /// Adds a button
  void addButton(Button button) {
    _buttonManager.addButton(button);
    _handleGetButtons();
  }

  /// Updates a button
  void updateButton(Button button) {
    _buttonManager.updateButton(button);
    _handleGetButtons();
  }

  /// Deletes a button
  void deleteButton(String id) {
    _buttonManager.deleteButton(id);
    _handleGetButtons();
  }
}
