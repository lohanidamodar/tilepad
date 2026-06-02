import 'dart:async';
import 'package:flutter/foundation.dart'; // Add Flutter foundation import
import 'package:shared_preferences/shared_preferences.dart';

import '../models/button.dart';
import '../models/message.dart';
import '../models/client_info.dart';
import '../network/websocket_service.dart';
import '../network/discovery_service.dart';
import '../network/discovery_service_stub.dart';
import '../utils/friendly_name.dart';
import 'button_manager.dart';
import 'command_executor.dart';

/// Server class that handles client connections and executes commands
class MarcoServer {
  /// The WebSocket service for client communication
  final ServerWebSocketService _webSocketService = ServerWebSocketService();

  /// The UDP discovery service for broadcasting server presence
  final DiscoveryService _discoveryService = createDiscoveryService();

  /// The button manager
  final ButtonManager _buttonManager = ButtonManager();

  /// The command executor
  final CommandExecutor _commandExecutor = CommandExecutor();

  /// Stream controller for client connection events
  final _clientsController = StreamController<List<ClientInfo>>.broadcast();

  /// Stream controller for server status events
  final _serverStatusController = StreamController<ServerStatus>.broadcast();

  /// The port to listen on
  int _port;

  /// The server's friendly name (shown to clients during discovery).
  String _name = 'MarcoDeck Server';

  /// Whether the server is running
  bool _isRunning = false;

  /// List of connected clients
  List<ClientInfo> _connectedClients = [];

  /// Creates a new server
  // A named parameter can't be a private initializing formal (`this._port`),
  // so assign it in the initializer list instead.
  // ignore: prefer_initializing_formals
  MarcoServer({int port = 8080}) : _port = port;

  /// Gets the server's IP address
  Future<String> getServerIp() async {
    return await _commandExecutor.getServerIpAddress();
  }

  /// Gets the server's port
  int get serverPort => _port;

  /// The server's friendly name shown to clients.
  String get name => _name;

  /// Loads the persisted server name, generating a random friendly one on
  /// first run (mirrors how the client names itself).
  Future<void> loadName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('server_name');
      if (saved != null && saved.isNotEmpty) {
        _name = saved;
      } else {
        _name = generateFriendlyName();
        await prefs.setString('server_name', _name);
      }
    } catch (e) {
      debugPrint('Error loading server name: $e');
    }
  }

  /// Updates and persists the server's friendly name. The new name is
  /// broadcast to clients after the next server (re)start.
  Future<void> setName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _name = trimmed;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_name', trimmed);
    } catch (e) {
      debugPrint('Error saving server name: $e');
    }
  }

  /// Sets the server port
  Future<void> setPort(int port) async {
    if (_isRunning) {
      throw Exception('Cannot change port while server is running');
    }
    _port = port;
  }

  /// Gets whether the server is running
  bool get isRunning => _isRunning;

  /// Gets the list of all configured pages
  List<Page> get pages => _buttonManager.pages;

  /// Gets the list of all configured buttons (from all pages)
  List<Button> get buttons => _buttonManager.buttons;

  /// Gets the list of connected clients
  List<ClientInfo> get connectedClients => _connectedClients;

  /// Stream of connected clients updates
  Stream<List<ClientInfo>> get clientsStream => _clientsController.stream;

  /// Stream of server status updates
  Stream<ServerStatus> get serverStatusStream => _serverStatusController.stream;

  /// Starts the server
  Future<bool> start() async {
    try {
      // If server is already running, return true
      if (_isRunning) {
        return true;
      }

      // Make sure we have a friendly name to advertise.
      await loadName();

      // Initialize button manager
      await _buttonManager.initialize();

      // Start WebSocket server
      final success = await _webSocketService.start(_port);
      if (!success) {
        _notifyServerStatus(
          ServerStatusType.error,
          'Failed to start server on port $_port',
        );
        return false;
      }

      _isRunning = true;
      _notifyServerStatus(
        ServerStatusType.started,
        'Server started on port $_port',
      );

      // Start UDP broadcasting for auto-discovery
      final serverIp = await getServerIp();
      await _discoveryService.startBroadcasting(
        serverName: '$_name ($serverIp)',
        port: _port,
      );
      debugPrint('UDP discovery broadcasting started');

      // Listen for client messages
      _webSocketService.messageStream.listen(_handleClientMessage);

      // Listen for client connections and disconnections
      _webSocketService.clientConnectionStream.listen(_handleClientConnection);

      // Initialize connected clients list
      _updateConnectedClients();

      return true;
    } catch (e) {
      debugPrint('Failed to start server: $e');
      _notifyServerStatus(ServerStatusType.error, 'Error starting server: $e');
      return false;
    }
  }

  /// Restarts the server, optionally with a new port
  Future<bool> restart({int? newPort}) async {
    try {
      _notifyServerStatus(ServerStatusType.restarting, 'Restarting server...');

      // Stop the server if it's running
      await stop();

      // Update port if a new one is provided
      if (newPort != null) {
        _port = newPort;
      }

      // Start the server again
      return await start();
    } catch (e) {
      debugPrint('Failed to restart server: $e');
      _notifyServerStatus(
        ServerStatusType.error,
        'Error restarting server: $e',
      );
      return false;
    }
  }

  /// Notifies listeners about server status changes
  void _notifyServerStatus(ServerStatusType type, String message) {
    _serverStatusController.add(ServerStatus(type: type, message: message));
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
      // Stop UDP broadcasting
      await _discoveryService.stopBroadcasting();
      debugPrint('UDP discovery broadcasting stopped');

      await _webSocketService.close();
      _isRunning = false;
      _connectedClients = [];
      _clientsController.add(_connectedClients);
      _notifyServerStatus(ServerStatusType.stopped, 'Server stopped');
    }
  }

  /// Handles a message from a client
  void _handleClientMessage(Message message) async {
    switch (message.type) {
      case MessageType.connect:
        // Send connect acknowledgment
        _webSocketService.sendMessage(Message(type: MessageType.connectAck));

        // Send pages with buttons to the newly connected client
        _sendPagesToClient();
        break;

      case MessageType.getButtons:
        // Send pages with buttons
        _sendPagesToClient();
        break;

      case MessageType.buttonPress:
        _handleButtonPress(message.payload);
        break;

      case MessageType.getWindows:
        _webSocketService.sendMessage(
          Message(
            type: MessageType.windowsResponse,
            payload:
                _commandExecutor.listWindows().map((w) => w.toJson()).toList(),
          ),
        );
        break;

      default:
        // Unknown message type
        debugPrint('Unknown message type: ${message.type}');
        break;
    }
  }

  /// Sends all pages with their buttons to the client
  void _sendPagesToClient() {
    _webSocketService.sendMessage(
      Message(
        type: MessageType.pagesResponse,
        payload: _buttonManager.pages.map((p) => p.toJson()).toList(),
      ),
    );
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
      final CommandResult result;
      final promptType = button.promptActionType;
      if (promptType == ActionType.promptText) {
        // Type the text the client supplied at press time.
        final text = (payload['text'] as String?) ?? '';
        result = await _commandExecutor.executeTypeText(text);
      } else if (promptType == ActionType.promptKeystroke) {
        // Send the key combination the client chose at press time.
        final key = (payload['key'] as String?) ?? '';
        final modifiers =
            (payload['modifiers'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[];
        result = await _commandExecutor.executeKeystroke(key, modifiers);
      } else if (promptType == ActionType.selectWindow) {
        // Bring the window the client chose to the foreground.
        final windowId = (payload['windowId'] as String?) ?? '';
        result = await _commandExecutor.activateWindow(windowId);
      } else {
        result = await _commandExecutor.execute(button);
      }
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

  /// Executes a button's actions directly on the server (for testing)
  Future<CommandResult> executeButtonLocally(Button button) async {
    try {
      // Use the command executor to execute the button's actions
      final result = await _commandExecutor.execute(button);
      return result;
    } catch (e) {
      // If an exception occurs, return a failed result
      return CommandResult(
        success: false,
        output: '',
        error: 'Error executing command: $e',
      );
    }
  }

  /// Adds a new page
  void addPage(Page page) {
    _buttonManager.addPage(page);
    _broadcastPages();
  }

  /// Updates an existing page
  bool updatePage(Page page) {
    final result = _buttonManager.updatePage(page);
    if (result) {
      _broadcastPages();
    }
    return result;
  }

  /// Deletes a page
  bool deletePage(String id) {
    final result = _buttonManager.deletePage(id);
    if (result) {
      _broadcastPages();
    }
    return result;
  }

  /// Reorders pages
  void reorderPages(List<Page> newOrder) {
    _buttonManager.reorderPages(newOrder);
    _broadcastPages();
  }

  /// Adds a new button to a specific page
  bool addButton(Button button, String pageId) {
    final result = _buttonManager.addButton(button, pageId);
    if (result) {
      _broadcastPages();
    }
    return result;
  }

  /// Updates an existing button
  void updateButton(Button button) {
    _buttonManager.updateButton(button);
    _broadcastPages();
  }

  /// Deletes a button
  void deleteButton(String id) {
    _buttonManager.deleteButton(id);
    _broadcastPages();
  }

  /// Moves a button to another page
  bool moveButton(String buttonId, String targetPageId) {
    final result = _buttonManager.moveButton(buttonId, targetPageId);
    if (result) {
      _broadcastPages();
    }
    return result;
  }

  /// Broadcasts the pages and buttons to all connected clients
  void _broadcastPages() {
    if (_isRunning) {
      _webSocketService.broadcast(
        Message(
          type: MessageType.pagesResponse,
          payload: _buttonManager.pages.map((p) => p.toJson()).toList(),
        ),
      );
    }
  }

  /// Disposes the server resources
  void dispose() async {
    await stop();
    await _discoveryService.dispose();
    await _clientsController.close();
    await _serverStatusController.close();
  }
}

/// Enum for server status types
enum ServerStatusType {
  /// Server has started
  started,

  /// Server is stopping
  stopped,

  /// Server is restarting
  restarting,

  /// Server encountered an error
  error,
}

/// Class representing server status
class ServerStatus {
  /// The status type
  final ServerStatusType type;

  /// Status message
  final String message;

  /// Creates a new server status
  ServerStatus({required this.type, required this.message});
}
