import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // Add Flutter foundation import
import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
import 'plugins/plugin_host.dart';
import 'plugins/plugin_manager.dart';
import 'plugins/plugin_manifest.dart';
import 'plugins/plugin_registry.dart';
import 'plugins/state_store.dart';
import 'system_info.dart';

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

  /// Loopback port the plugin host listens on for plugin processes.
  final int _pluginPort;

  /// Shared live-state store fed by both plugins and the system-info sampler.
  final StateStore _stateStore = StateStore();

  /// Plugin subsystem (null until the server is started).
  PluginHost? _pluginHost;
  PluginRegistry? _pluginRegistry;
  PluginManager? _pluginManager;
  SystemInfoService? _systemInfo;
  StreamSubscription<StateEntry>? _stateSub;
  Directory? _pluginsDir;

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

  /// IP addresses blocked from connecting. Persisted across restarts.
  final Set<String> _blockedIps = {};

  /// Creates a new server
  // A named parameter can't be a private initializing formal (`this._port`),
  // so assign these in the initializer list instead.
  // ignore_for_file: prefer_initializing_formals
  MarcoServer({int port = 8080, int pluginPort = 8091})
      : _port = port,
        _pluginPort = pluginPort;

  /// The installed plugins, or empty if the server has not started yet.
  List<InstalledPlugin> get plugins => _pluginRegistry?.plugins ?? const [];

  /// Plugin discovery/parse errors surfaced for the UI.
  List<String> get pluginErrors => _pluginRegistry?.errors ?? const [];

  /// Whether a plugin is currently connected to the host.
  bool isPluginConnected(String id) => _pluginHost?.isConnected(id) ?? false;

  /// Emits a pluginId whenever its connection state changes, so the UI can
  /// refresh enabled/connected status live. Empty if the server isn't started.
  Stream<String> get pluginConnectionChanges =>
      _pluginHost?.connectionChanges ?? const Stream.empty();

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

  /// The IP addresses currently blocked from connecting.
  Set<String> get blockedIps => Set.unmodifiable(_blockedIps);

  /// Loads the persisted IP blocklist and applies it to the running service.
  Future<void> _loadBlockedIps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _blockedIps
        ..clear()
        ..addAll(prefs.getStringList('blocked_ips') ?? const []);
      _webSocketService.updateBlockedIps(_blockedIps);
    } catch (e) {
      debugPrint('Error loading blocked IPs: $e');
    }
  }

  Future<void> _saveBlockedIps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('blocked_ips', _blockedIps.toList());
    } catch (e) {
      debugPrint('Error saving blocked IPs: $e');
    }
  }

  /// Forcibly disconnects a connected client by its [ClientInfo.id].
  void disconnectClient(String clientId) {
    _webSocketService.disconnectClient(clientId);
  }

  /// Blocks [ip] from connecting, disconnecting any current client from it.
  Future<void> blockIp(String ip) async {
    if (ip.isEmpty || ip == 'Unknown') return;
    _blockedIps.add(ip);
    _webSocketService.updateBlockedIps(_blockedIps);
    await _saveBlockedIps();
  }

  /// Removes [ip] from the blocklist so it may connect again.
  Future<void> unblockIp(String ip) async {
    _blockedIps.remove(ip);
    _webSocketService.updateBlockedIps(_blockedIps);
    await _saveBlockedIps();
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

      // Apply the persisted IP blocklist to the freshly-started service.
      await _loadBlockedIps();

      // Start UDP broadcasting for auto-discovery
      final serverIp = await getServerIp();
      await _discoveryService.startBroadcasting(
        serverName: '$_name ($serverIp)',
        port: _port,
      );
      debugPrint('UDP discovery broadcasting started');

      // Listen for client messages (tagged with the sender so connect-time
      // replays can target just that client instead of broadcasting).
      _webSocketService.addressedMessageStream.listen(
        (m) => _handleClientMessage(m.message, m.clientId),
      );

      // Listen for client connections and disconnections
      _webSocketService.clientConnectionStream.listen(_handleClientConnection);

      // Initialize connected clients list
      _updateConnectedClients();

      // Bring up the plugin subsystem (best-effort; failures here must not stop
      // the core server).
      _startStateSources();
      await _startPlugins();

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

      _systemInfo?.stop();
      _systemInfo = null;
      await _stateSub?.cancel();
      _stateSub = null;
      await _stopPlugins();

      await _webSocketService.close();
      _isRunning = false;
      _connectedClients = [];
      _clientsController.add(_connectedClients);
      _notifyServerStatus(ServerStatusType.stopped, 'Server stopped');
    }
  }

  // ---------------------------------------------------------------------------
  // Plugin subsystem
  // ---------------------------------------------------------------------------

  /// Directory where plugins live: `<app support>/plugins`.
  Future<Directory> _pluginsDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'plugins'));
  }

  /// Copies first-party plugins bundled under `assets/plugins/<folder>/` into
  /// the on-disk plugins directory so they're discovered like any installed
  /// plugin. Re-seeds only when the bundled version differs from what's on disk,
  /// so a user's enabled/settings state (kept separately in registry.json) and
  /// any local edits survive across launches.
  Future<void> _seedBundledPlugins(Directory pluginsDir) async {
    try {
      const prefix = 'assets/plugins/';
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final byFolder = <String, List<String>>{};
      for (final asset in manifest.listAssets()) {
        if (!asset.startsWith(prefix)) continue;
        final rest = asset.substring(prefix.length);
        final slash = rest.indexOf('/');
        if (slash <= 0) continue;
        byFolder.putIfAbsent(rest.substring(0, slash), () => []).add(asset);
      }
      for (final files in byFolder.values) {
        await _seedPlugin(pluginsDir, files);
      }
    } catch (e) {
      debugPrint('Failed to seed bundled plugins: $e');
    }
  }

  Future<void> _seedPlugin(Directory pluginsDir, List<String> assetPaths) async {
    String? manifestAsset;
    for (final a in assetPaths) {
      if (a.endsWith('/manifest.json')) {
        manifestAsset = a;
        break;
      }
    }
    if (manifestAsset == null) return;

    final bundled =
        jsonDecode(await rootBundle.loadString(manifestAsset)) as Map<String, dynamic>;
    final id = bundled['id'] as String?;
    final version = bundled['version'] as String? ?? '';
    if (id == null || id.isEmpty) return;

    final target = Directory(p.join(pluginsDir.path, id));
    final installedManifest = File(p.join(target.path, 'manifest.json'));
    if (await installedManifest.exists()) {
      try {
        final cur =
            jsonDecode(await installedManifest.readAsString()) as Map<String, dynamic>;
        if ((cur['version'] as String? ?? '') == version) return; // up to date
      } catch (_) {/* malformed → re-seed */}
    }

    await target.create(recursive: true);
    final runCommand = (bundled['run'] as Map<String, dynamic>?) ?? const {};
    final runTarget = _runTargetBasename(runCommand);
    for (final a in assetPaths) {
      final name = a.substring(a.lastIndexOf('/') + 1);
      final data = await rootBundle.load(a);
      final file = File(p.join(target.path, name));
      await file.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      // Make a bundled native binary executable on POSIX systems.
      if (!Platform.isWindows && name == runTarget) {
        try {
          await Process.run('chmod', ['+x', file.path]);
        } catch (_) {}
      }
    }
    debugPrint('Seeded bundled plugin $id ($version)');
  }

  /// The plugin-folder-relative file the current platform's run command
  /// launches (e.g. `obs-plugin` / `obs-plugin.exe`), or null when the command
  /// is an interpreter like `dart plugin.dart`.
  String? _runTargetBasename(Map<String, dynamic> run) {
    final key = Platform.isWindows
        ? 'windows'
        : (Platform.isMacOS ? 'macos' : 'linux');
    final cmd = (run[key] as String?)?.trim() ?? '';
    if (cmd.isEmpty) return null;
    final first = cmd.split(RegExp(r'\s+')).first;
    // Only treat it as a bundled binary if it has no path separators and isn't
    // an interpreter invocation (which has a second token).
    if (cmd.contains(' ')) return null;
    return first.replaceFirst('./', '');
  }

  /// Starts the plugin host, discovers plugins, launches enabled ones, and wires
  /// action invocation + live-state forwarding. Best-effort: never throws.
  /// Starts the live-state sources: forwards the shared [StateStore] to clients
  /// and starts the built-in system-info sampler. These work even if the plugin
  /// subsystem fails.
  void _startStateSources() {
    _stateSub = _stateStore.changes.listen((entry) {
      if (!_isRunning) return;
      _webSocketService.broadcast(
        Message(type: MessageType.stateUpdate, payload: entry.toJson()),
      );
    });
    _systemInfo = SystemInfoService(_stateStore)..start();
  }

  Future<void> _startPlugins() async {
    try {
      // Plugins publish into the shared store so plugin + system live tiles
      // flow through one pipeline.
      final host = PluginHost(stateStore: _stateStore);
      await host.start(port: _pluginPort);
      final dir = await _pluginsDirectory();
      _pluginsDir = dir;
      // Seed first-party plugins bundled with the app so they appear in the
      // list out of the box (both debug and release), then scan.
      await _seedBundledPlugins(dir);
      final registry = PluginRegistry(dir);
      await registry.load();
      final manager = PluginManager(registry: registry, host: host);

      _pluginHost = host;
      _pluginRegistry = registry;
      _pluginManager = manager;

      // Route plugin actions through the host.
      _commandExecutor.pluginInvoker = host.invoke;

      await manager.startAll();
      debugPrint('Plugin subsystem started (${registry.plugins.length} found)');
    } catch (e) {
      debugPrint('Plugin subsystem failed to start: $e');
    }
  }

  Future<void> _stopPlugins() async {
    await _pluginManager?.stopAll();
    await _pluginHost?.stop();
    _commandExecutor.pluginInvoker = null;
    _pluginHost = null;
    _pluginManager = null;
    _pluginRegistry = null;
  }

  /// Replays the current live-state snapshot to a single client (on connect).
  void _sendStateSnapshot(String clientId) {
    for (final entry in _stateStore.snapshot()) {
      _webSocketService.sendMessageToClient(
        clientId,
        Message(type: MessageType.stateUpdate, payload: entry.toJson()),
      );
    }
  }

  /// Installs a plugin from a `.zip` and returns its id.
  Future<String> installPlugin(File zip) async {
    final registry = _pluginRegistry;
    if (registry == null) throw StateError('Server not started');
    final installed = await registry.installFromZip(zip);
    return installed.manifest.id;
  }

  /// Installs a plugin by copying a source folder into the plugins directory.
  Future<String> installPluginFromDirectory(Directory source) async {
    final registry = _pluginRegistry;
    if (registry == null) throw StateError('Server not started');
    final installed = await registry.installFromDirectory(source);
    return installed.manifest.id;
  }

  /// Installs a dropped/picked path which may be a plugin folder or a `.zip`.
  /// Throws [PluginInstallException] if it is neither a valid folder (with a
  /// manifest) nor a zip.
  Future<String> installPluginFromPath(String path) async {
    if (await Directory(path).exists()) {
      return installPluginFromDirectory(Directory(path));
    }
    if (await File(path).exists() && path.toLowerCase().endsWith('.zip')) {
      return installPlugin(File(path));
    }
    throw PluginInstallException(
      'Drop a plugin folder (with a manifest.json) or a .zip file',
    );
  }

  /// Absolute path to the plugins directory (empty until the server starts).
  String get pluginsDirectoryPath => _pluginsDir?.path ?? '';

  /// Re-scans the plugins directory to pick up newly added plugin folders.
  Future<void> rescanPlugins() async {
    await _pluginRegistry?.load();
  }

  /// Opens the plugins directory in the OS file manager so the user can drop a
  /// plugin folder into it.
  Future<void> openPluginsFolder() async {
    final dir = _pluginsDir;
    if (dir == null) return;
    if (!await dir.exists()) await dir.create(recursive: true);
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [dir.path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [dir.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [dir.path]);
      }
    } catch (e) {
      debugPrint('Failed to open plugins folder: $e');
    }
  }

  /// Enables a plugin (launches its process).
  Future<void> enablePlugin(String id) => _pluginManager?.enable(id) ?? Future.value();

  /// Disables a plugin (stops its process).
  Future<void> disablePlugin(String id) =>
      _pluginManager?.disable(id) ?? Future.value();

  /// Removes a plugin entirely.
  Future<void> removePlugin(String id) async {
    await _pluginManager?.disable(id);
    await _pluginRegistry?.remove(id);
  }

  /// Updates and persists a plugin's settings, pushing them to the process.
  Future<void> updatePluginSettings(String id, Map<String, dynamic> values) =>
      _pluginManager?.updateSettings(id, values) ?? Future.value();

  /// Requests dynamic option values for a plugin select field.
  Future<List<PluginFieldOption>> requestPluginList(
    String pluginId,
    String listId, {
    Map<String, dynamic> fields = const {},
  }) async {
    final host = _pluginHost;
    if (host == null) return const [];
    try {
      return await host.requestList(pluginId, listId, fields: fields);
    } catch (e) {
      debugPrint('requestPluginList failed: $e');
      return const [];
    }
  }

  /// Handles a message from a client. [clientId] identifies the sender so
  /// replies (acks, pages, state snapshot, results) go only to that client.
  void _handleClientMessage(Message message, String clientId) async {
    switch (message.type) {
      case MessageType.connect:
        // Send connect acknowledgment
        _webSocketService.sendMessageToClient(
          clientId,
          Message(type: MessageType.connectAck),
        );

        // Send pages with buttons to the newly connected client
        _sendPagesToClient(clientId);
        // Replay current live plugin state so live tiles render immediately.
        _sendStateSnapshot(clientId);
        break;

      case MessageType.getButtons:
        // Send pages with buttons
        _sendPagesToClient(clientId);
        _sendStateSnapshot(clientId);
        break;

      case MessageType.buttonPress:
        _handleButtonPress(message.payload, clientId);
        break;

      case MessageType.getWindows:
        _webSocketService.sendMessageToClient(
          clientId,
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

  /// Sends all pages with their buttons to a single client.
  void _sendPagesToClient(String clientId) {
    _webSocketService.sendMessageToClient(
      clientId,
      Message(
        type: MessageType.pagesResponse,
        payload: _buttonManager.pages.map((p) => p.toJson()).toList(),
      ),
    );
  }

  /// Handles a button press message
  void _handleButtonPress(dynamic payload, String clientId) async {
    if (payload == null || !payload.containsKey('buttonId')) {
      return;
    }

    final buttonId = payload['buttonId'];
    final button = _buttonManager.getButton(buttonId);

    if (button == null) {
      _webSocketService.sendMessageToClient(
        clientId,
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
      _webSocketService.sendMessageToClient(
        clientId,
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
      _webSocketService.sendMessageToClient(
        clientId,
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

  /// The button library.
  List<Button> get libraryButtons => _buttonManager.buttons;

  /// Adds a button to the library.
  void addLibraryButton(Button button) {
    _buttonManager.addLibraryButton(button);
    _broadcastPages();
  }

  /// Updates a library button (reflected on every page that places it).
  void updateButton(Button button) {
    _buttonManager.updateButton(button);
    _broadcastPages();
  }

  /// Deletes a library button and its placements everywhere.
  void deleteButton(String id) {
    _buttonManager.deleteButton(id);
    _broadcastPages();
  }

  /// Places a library button on a page at the given size.
  Tile? addTile(String pageId, String buttonId, {int colSpan = 1, int rowSpan = 1}) {
    final tile = _buttonManager.addTile(
      pageId,
      buttonId,
      colSpan: colSpan,
      rowSpan: rowSpan,
    );
    if (tile != null) _broadcastPages();
    return tile;
  }

  /// Removes a tile (placement) from a page.
  bool removeTile(String pageId, String tileId) {
    final result = _buttonManager.removeTile(pageId, tileId);
    if (result) _broadcastPages();
    return result;
  }

  /// Resizes a tile on a page.
  bool resizeTile(String pageId, String tileId, int colSpan, int rowSpan) {
    final result = _buttonManager.resizeTile(pageId, tileId, colSpan, rowSpan);
    if (result) _broadcastPages();
    return result;
  }

  /// Reorders a tile within a page.
  bool reorderTiles(String pageId, int oldIndex, int newIndex) {
    final result = _buttonManager.reorderTiles(pageId, oldIndex, newIndex);
    if (result) _broadcastPages();
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
  Future<void> dispose() async {
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
