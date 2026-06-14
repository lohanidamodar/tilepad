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
/// Once a [TilepadServer] is attached the tray becomes a live mini-dashboard:
/// the menu and tooltip show the server state, address and connected device
/// count, and offer start/stop/restart and copy-address without opening the
/// window.
class SystemTrayManager with TrayListener, WindowListener {
  static final SystemTrayManager _instance = SystemTrayManager._internal();
  factory SystemTrayManager() => _instance;

  SystemTrayManager._internal();

  bool _isInitialized = false;

  TilepadServer? _server;
  StreamSubscription<ServerStatus>? _statusSub;
  StreamSubscription<List<dynamic>>? _clientsSub;

  /// Cached state rendered into the menu/tooltip.
  String _serverIp = '';
  int _clientCount = 0;

  /// Signature of the last menu actually applied, so repeated status/client
  /// events that change nothing don't rebuild the native menu (rebuilding it
  /// makes the tray icon flicker on some platforms).
  String _lastMenuSignature = '';

  /// Initialize the system tray.
  ///
  /// With [startHidden] the window is not shown — the app starts as just the
  /// tray icon (used by the launch-at-login entry via `--hidden`).
  Future<void> initSystemTray({bool startHidden = false}) async {
    if (_isInitialized) return;

    debugPrint('Initializing window manager and system tray...');

    // Initialize window manager
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1120, 740),
      minimumSize: Size(640, 560),
      center: true,
      title: 'Tilepad Server',
      skipTaskbar: false,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setPreventClose(true);
      if (startHidden) {
        // The Windows runner already skips its first-frame auto-show when
        // `--hidden` is passed; on Linux/macOS the runner shows the window
        // natively, so hide it again here (it may flash briefly).
        await windowManager.hide();
      } else {
        await windowManager.show();
        await windowManager.focus();
      }
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
      await trayManager.setToolTip('Tilepad Server');

      // Create menu items
      await _refreshMenu();

      _isInitialized = true;
      debugPrint('System tray initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize system tray: $e');
      if (startHidden) {
        // Without a tray icon a hidden app would be unreachable; fall back to
        // showing the window.
        await showWindow();
      }
    }
  }

  /// Attaches the server so the tray can show live status and control it.
  void attachServer(TilepadServer server) {
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
  /// Skipped when nothing visible changed.
  Future<void> _refreshMenu() async {
    final server = _server;
    final running = server?.isRunning ?? false;
    final address = _address;

    final signature =
        '${server != null}|$running|$address|$_clientCount';
    if (signature == _lastMenuSignature) return;
    _lastMenuSignature = signature;

    final status = server == null
        ? 'Tilepad Server'
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
        MenuItem(key: _kMenuKeyShow, label: 'Open Tilepad'),
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
            ? 'Tilepad Server'
            : running
                ? 'Tilepad — $status ($devices)'
                : 'Tilepad — Stopped',
      );
    } catch (e) {
      debugPrint('Failed to update tray menu: $e');
    }
  }

  /// Show the application window.
  Future<void> showWindow() async {
    try {
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }
      await windowManager.show();
      await windowManager.focus();
      // While the window is hidden Flutter disables frame scheduling; if the
      // resume notification races the show, nothing repaints the restored
      // surface and the window stays white. Force one frame to repaint it
      // (scheduleForcedFrame ignores the frames-disabled state).
      WidgetsBinding.instance.scheduleForcedFrame();
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
