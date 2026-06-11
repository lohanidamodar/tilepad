import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../server/server.dart';

/// Menu item keys for the system tray context menu.
const String _kMenuKeyShow = 'show_window';
const String _kMenuKeyCopyAddress = 'copy_address';
const String _kMenuKeyToggleServer = 'toggle_server';
const String _kMenuKeyRestartServer = 'restart_server';
const String _kMenuKeyExit = 'exit_app';

/// Manager for system tray functionality.
///
/// Once a [MarcoServer] is attached the tray becomes a live mini-dashboard:
/// the menu and tooltip show the server state, address and connected device
/// count, and offer start/stop/restart and copy-address without opening the
/// window.
class SystemTrayManager with TrayListener, WindowListener {
  static final SystemTrayManager _instance = SystemTrayManager._internal();
  factory SystemTrayManager() => _instance;

  SystemTrayManager._internal();

  bool _isInitialized = false;

  MarcoServer? _server;
  StreamSubscription<ServerStatus>? _statusSub;
  StreamSubscription<List<dynamic>>? _clientsSub;

  /// Cached state rendered into the menu/tooltip.
  String _serverIp = '';
  int _clientCount = 0;

  /// Initialize the system tray.
  Future<void> initSystemTray() async {
    if (_isInitialized) return;

    debugPrint('Initializing window manager and system tray...');

    // Initialize window manager
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1120, 740),
      minimumSize: Size(640, 560),
      center: true,
      title: 'MarcoDeck Server',
      skipTaskbar: false,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setPreventClose(true);
      await windowManager.show();
      await windowManager.focus();
    });

    // Listen for window and tray events.
    windowManager.addListener(this);
    trayManager.addListener(this);

    try {
      // Prepare the tray icon
      final String iconPath =
          Platform.isWindows ? 'assets/tray_icon.ico' : 'assets/tray_icon.png';
      debugPrint('Using tray icon: $iconPath');

      // Initialize system tray
      await trayManager.setIcon(iconPath);
      await trayManager.setToolTip('MarcoDeck Server');

      // Create menu items
      await _refreshMenu();

      _isInitialized = true;
      debugPrint('System tray initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize system tray: $e');
    }
  }

  /// Attaches the server so the tray can show live status and control it.
  void attachServer(MarcoServer server) {
    _server = server;
    _statusSub?.cancel();
    _clientsSub?.cancel();
    _statusSub = server.serverStatusStream.listen((_) => _onServerChanged());
    _clientsSub = server.clientsStream.listen((clients) {
      _clientCount = clients.length;
      _refreshMenu();
    });
    _onServerChanged();
  }

  /// Detaches the server (e.g. when the app shell is disposed).
  void detachServer() {
    _statusSub?.cancel();
    _clientsSub?.cancel();
    _statusSub = null;
    _clientsSub = null;
    _server = null;
  }

  Future<void> _onServerChanged() async {
    final server = _server;
    if (server != null && server.isRunning) {
      try {
        _serverIp = await server.getServerIp();
      } catch (_) {
        _serverIp = '';
      }
    }
    await _refreshMenu();
  }

  /// The server's address, shown in the menu and copied to the clipboard.
  String get _address {
    final server = _server;
    if (server == null || _serverIp.isEmpty) return '';
    return 'ws://$_serverIp:${server.serverPort}';
  }

  /// (Re)builds the tray menu and tooltip from the current server state.
  Future<void> _refreshMenu() async {
    final server = _server;
    final running = server?.isRunning ?? false;
    final address = _address;

    final status = server == null
        ? 'MarcoDeck Server'
        : running
            ? 'Running${address.isEmpty ? '' : ' on $address'}'
            : 'Stopped';
    final devices =
        '$_clientCount device${_clientCount == 1 ? '' : 's'} connected';

    final menu = Menu(
      items: [
        MenuItem(label: status, disabled: true),
        if (running) MenuItem(label: devices, disabled: true),
        MenuItem.separator(),
        MenuItem(key: _kMenuKeyShow, label: 'Open MarcoDeck'),
        if (running && address.isNotEmpty)
          MenuItem(key: _kMenuKeyCopyAddress, label: 'Copy server address'),
        if (server != null) ...[
          MenuItem.separator(),
          MenuItem(
            key: _kMenuKeyToggleServer,
            label: running ? 'Stop server' : 'Start server',
          ),
          if (running)
            MenuItem(key: _kMenuKeyRestartServer, label: 'Restart server'),
        ],
        MenuItem.separator(),
        MenuItem(key: _kMenuKeyExit, label: 'Exit'),
      ],
    );

    try {
      await trayManager.setContextMenu(menu);
      await trayManager.setToolTip(
        server == null
            ? 'MarcoDeck Server'
            : running
                ? 'MarcoDeck — $status ($devices)'
                : 'MarcoDeck — Stopped',
      );
    } catch (e) {
      debugPrint('Failed to update tray menu: $e');
    }
  }

  /// Show the application window.
  Future<void> showWindow() async {
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      debugPrint('Error showing window: $e');
    }
  }

  /// Hide the application window to tray.
  Future<void> hideToTray() async {
    try {
      // Make sure system tray is initialized
      if (!_isInitialized) {
        await initSystemTray();
      }

      // Hide the window
      await windowManager.hide();
    } catch (e) {
      debugPrint('Error hiding window to tray: $e');
    }
  }

  /// Exit the application, stopping the server first so clients see a clean
  /// disconnect instead of a dead socket.
  Future<void> exitApplication() async {
    try {
      await _server?.stop().timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('Error stopping server on exit: $e');
    }
    exit(0);
  }

  // --- TrayListener ---

  @override
  void onTrayIconMouseDown() {
    // Left click: show the window on Windows, open the menu elsewhere.
    if (Platform.isWindows) {
      showWindow();
    } else {
      trayManager.popUpContextMenu();
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    // Right click: open the menu on Windows, show the window elsewhere.
    if (Platform.isWindows) {
      trayManager.popUpContextMenu();
    } else {
      showWindow();
    }
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case _kMenuKeyShow:
        showWindow();
        break;
      case _kMenuKeyCopyAddress:
        final address = _address;
        if (address.isNotEmpty) {
          await Clipboard.setData(ClipboardData(text: address));
        }
        break;
      case _kMenuKeyToggleServer:
        final server = _server;
        if (server == null) break;
        if (server.isRunning) {
          await server.stop();
        } else {
          await server.start();
        }
        _onServerChanged();
        break;
      case _kMenuKeyRestartServer:
        await _server?.restart();
        _onServerChanged();
        break;
      case _kMenuKeyExit:
        exitApplication();
        break;
    }
  }

  // --- WindowListener ---

  @override
  void onWindowClose() async {
    await hideToTray();
  }
}
