import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/button.dart';
import '../models/message.dart';
import '../network/websocket_service.dart';

/// Client class that handles communication with the server
class MarcoClient {
  /// The WebSocket service for server communication
  final ClientWebSocketService _webSocketService = ClientWebSocketService();

  /// List of available buttons
  List<Button> _buttons = [];

  /// Stream controller for buttons
  final _buttonsController = StreamController<List<Button>>.broadcast();

  /// Stream controller for connection status
  final _connectionController = StreamController<bool>.broadcast();

  /// Stream controller for command results
  final _resultController = StreamController<CommandResultEvent>.broadcast();

  /// Last saved server address
  String? _serverAddress;

  /// Whether the client is connected to the server
  bool _isConnected = false;

  /// Stream of buttons
  Stream<List<Button>> get buttonsStream => _buttonsController.stream;

  /// Stream of connection status
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Stream of command results
  Stream<CommandResultEvent> get resultStream => _resultController.stream;

  /// Whether the client is connected to the server
  bool get isConnected => _isConnected;

  /// The server address
  String? get serverAddress => _serverAddress;

  /// List of available buttons
  List<Button> get buttons => List.unmodifiable(_buttons);

  /// Creates a new client
  MarcoClient() {
    _loadSavedServer();

    // Listen for server messages
    _webSocketService.messageStream.listen(_handleServerMessage);
  }

  /// Loads the saved server address from preferences
  Future<void> _loadSavedServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _serverAddress = prefs.getString('server_address');
    } catch (e) {
      print('Error loading saved server: $e');
    }
  }

  /// Saves the server address to preferences
  Future<void> _saveServerAddress(String address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_address', address);
      _serverAddress = address;
    } catch (e) {
      print('Error saving server address: $e');
    }
  }

  /// Connects to the server
  Future<bool> connect(String address) async {
    try {
      // Close existing connection if connected
      if (_isConnected) {
        await disconnect();
      }

      final success = await _webSocketService.connect(address);
      if (success) {
        _serverAddress = address;
        await _saveServerAddress(address);

        // Send connect message
        _webSocketService.sendMessage(Message(type: MessageType.connect));

        return true;
      }

      return false;
    } catch (e) {
      print('Error connecting to server: $e');
      return false;
    }
  }

  /// Disconnects from the server
  Future<void> disconnect() async {
    await _webSocketService.close();
    _isConnected = false;
    _connectionController.add(false);
    _buttons = [];
    _buttonsController.add(_buttons);
  }

  /// Presses a button
  void pressButton(String buttonId) {
    if (_isConnected) {
      _webSocketService.sendMessage(
        Message(type: MessageType.buttonPress, payload: {'buttonId': buttonId}),
      );
    }
  }

  /// Requests the available buttons from the server
  void requestButtons() {
    if (_isConnected) {
      _webSocketService.sendMessage(Message(type: MessageType.getButtons));
    }
  }

  /// Handles a message from the server
  void _handleServerMessage(Message message) {
    print('Received message: ${message.type}');

    switch (message.type) {
      case MessageType.connectAck:
        _isConnected = true;
        _connectionController.add(true);
        break;
      case MessageType.buttonsResponse:
        _handleButtonsResponse(message.payload);
        break;
      case MessageType.commandResult:
        _handleCommandResult(message.payload);
        break;
      case MessageType.error:
        print('Error from server: ${message.payload['error']}');
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
      _buttons = buttonsJson.map((json) => Button.fromJson(json)).toList();
      _buttonsController.add(_buttons);
    } catch (e) {
      print('Error handling buttons response: $e');
    }
  }

  /// Handles a command result message
  void _handleCommandResult(dynamic payload) {
    try {
      _resultController.add(
        CommandResultEvent(
          buttonId: payload['buttonId'],
          success: payload['success'],
          output: payload['output'],
          error: payload['error'],
        ),
      );
    } catch (e) {
      print('Error handling command result: $e');
    }
  }

  /// Disposes the client
  void dispose() async {
    await _webSocketService.close();
    await _buttonsController.close();
    await _connectionController.close();
    await _resultController.close();
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
