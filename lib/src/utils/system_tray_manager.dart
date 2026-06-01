import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Menu item keys for the system tray context menu.
const String _kMenuKeyShow = 'show_window';
const String _kMenuKeyExit = 'exit_app';

/// Manager for system tray functionality.
class SystemTrayManager with TrayListener, WindowListener {
  static final SystemTrayManager _instance = SystemTrayManager._internal();
  factory SystemTrayManager() => _instance;

  SystemTrayManager._internal();

  bool _isInitialized = false;

  /// Initialize the system tray.
  Future<void> initSystemTray() async {
    if (_isInitialized) return;

    debugPrint('Initializing window manager and system tray...');

    // Initialize window manager
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(800, 600),
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
      await _createMenu();

      _isInitialized = true;
      debugPrint('System tray initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize system tray: $e');
    }
  }

  /// Create a system tray menu.
  Future<void> _createMenu() async {
    final menu = Menu(
      items: [
        MenuItem(key: _kMenuKeyShow, label: 'Show MarcoDeck'),
        MenuItem.separator(),
        MenuItem(key: _kMenuKeyExit, label: 'Exit'),
      ],
    );
    await trayManager.setContextMenu(menu);
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

      // Show notification in system tray (if possible)
      try {
        await trayManager.setToolTip(
          'MarcoDeck Server is running in the background',
        );
      } catch (_) {}
    } catch (e) {
      debugPrint('Error hiding window to tray: $e');
    }
  }

  /// Exit the application.
  void exitApplication() {
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
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case _kMenuKeyShow:
        showWindow();
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
