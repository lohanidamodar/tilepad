import 'dart:io';
import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

/// Manager for system tray functionality
class SystemTrayManager {
  static final SystemTrayManager _instance = SystemTrayManager._internal();
  factory SystemTrayManager() => _instance;

  SystemTrayManager._internal();

  final SystemTray _systemTray = SystemTray();
  final Menu _menu = Menu();
  final AppWindow appWindow = AppWindow();
  bool _isInitialized = false;

  /// Initialize the system tray
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

    // Add window manager listener for close event
    windowManager.addListener(_WindowManagerListener(this));

    try {
      // Prepare the tray icon
      final String iconPath =
          Platform.isWindows ? 'assets/tray_icon.ico' : 'assets/tray_icon.png';
      debugPrint('Using tray icon: $iconPath');

      // Initialize system tray
      await _systemTray.initSystemTray(
        iconPath: iconPath,
        title: 'MarcoDeck Server',
        toolTip: 'MarcoDeck Server',
      );

      // Create menu items
      await _createMenu();

      // Handle system tray events
      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          Platform.isWindows
              ? appWindow.show()
              : _systemTray.popUpContextMenu();
        } else if (eventName == kSystemTrayEventRightClick) {
          Platform.isWindows
              ? _systemTray.popUpContextMenu()
              : appWindow.show();
        }
      });

      _isInitialized = true;
      debugPrint('System tray initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize system tray: $e');
    }
  }

  /// Create a system tray menu
  Future<void> _createMenu() async {
    // Create menu items
    final showItem = MenuItemLabel(
      label: 'Show MarcoDeck',
      onClicked: (base) async {
        await showWindow();
      },
    );

    final exitItem = MenuItemLabel(
      label: 'Exit',
      onClicked: (base) async {
        exitApplication();
      },
    );

    // Add items to menu
    await _menu.buildFrom([showItem, MenuSeparator(), exitItem]);

    // Set the menu
    await _systemTray.setContextMenu(_menu);
  }

  /// Show the application window
  Future<void> showWindow() async {
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      debugPrint('Error showing window: $e');
    }
  }

  /// Hide the application window to tray
  Future<void> hideToTray() async {
    try {
      // Make sure system tray is initialized
      if (!_isInitialized) {
        await initSystemTray();
      }

      // Hide the window
      await appWindow.hide();

      // Show notification in system tray (if possible)
      try {
        await _systemTray.setToolTip(
          'MarcoDeck Server is running in the background',
        );
      } catch (_) {}
    } catch (e) {
      debugPrint('Error hiding window to tray: $e');
    }
  }

  /// Exit the application
  void exitApplication() {
    exit(0);
  }
}

/// Custom window manager listener
class _WindowManagerListener extends WindowListener {
  final SystemTrayManager _trayManager;

  _WindowManagerListener(this._trayManager);

  @override
  void onWindowClose() async {
    await _trayManager.hideToTray();
  }
}
