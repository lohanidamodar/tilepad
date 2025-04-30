import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path_provider/path_provider.dart';

/// Manager for system tray functionality
class SystemTrayManager {
  static final SystemTrayManager _instance = SystemTrayManager._internal();
  factory SystemTrayManager() => _instance;

  SystemTrayManager._internal();

  bool _isInitialized = false;

  /// Initialize the system tray
  Future<void> initSystemTray() async {
    if (_isInitialized) return;

    debugPrint('Initializing window manager...');

    // Initialize window manager
    await windowManager.ensureInitialized();

    // Set window options
    await windowManager.setPreventClose(true);
    await windowManager.setTitle('MarcoDeck Server');
    await windowManager.setSize(const Size(800, 600));
    await windowManager.center();
    await windowManager.focus();
    await windowManager.show();

    _isInitialized = true;
    debugPrint('Window manager initialized');
  }

  /// Hide the application window to tray
  void hideToTray() async {
    await windowManager.hide();
  }

  /// Show the application window
  void showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  /// Exit the application
  void exitApplication() {
    exit(0);
  }
}
