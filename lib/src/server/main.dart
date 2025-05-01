import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'server.dart';
import 'server_screen.dart';
import '../utils/system_tray_manager.dart';
import '../utils/theme.dart';

/// Main entry point for the server app
void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager
  await SystemTrayManager().initSystemTray();

  // Run the app
  runApp(const MarcoDeckServerApp());
}

/// The MarcoDeck server application
class MarcoDeckServerApp extends StatefulWidget {
  /// Creates a new MarcoDeck server app
  const MarcoDeckServerApp({super.key});

  @override
  State<MarcoDeckServerApp> createState() => _MarcoDeckServerAppState();
}

class _MarcoDeckServerAppState extends State<MarcoDeckServerApp>
    with WindowListener {
  final _server = MarcoServer();
  final _trayManager = SystemTrayManager();
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    // Register window manager listener
    windowManager.addListener(this);
    // Load saved theme mode
    _loadThemeMode();
  }

  /// Loads the theme mode from shared preferences
  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt('themeMode') ?? 0;
    setState(() {
      _themeMode = ThemeMode.values[themeModeIndex];
    });
  }

  /// Saves the theme mode to shared preferences
  Future<void> _saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _server.stop();
    super.dispose();
  }

  // Handle window close event - minimize to background instead of closing
  @override
  void onWindowClose() {
    // Hide window instead of closing it
    _trayManager.hideToTray();
  }

  // Implement required WindowListener methods (empty implementations)
  @override
  void onWindowFocus() {}
  @override
  void onWindowBlur() {}
  @override
  void onWindowMaximize() {}
  @override
  void onWindowMinimize() {}
  @override
  void onWindowUnmaximize() {}
  @override
  void onWindowRestore() {}
  @override
  void onWindowResized() {}
  @override
  void onWindowMoved() {}
  @override
  void onWindowEnterFullScreen() {}
  @override
  void onWindowLeaveFullScreen() {}
  @override
  void onWindowDocked() {}
  @override
  void onWindowUndocked() {}

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MarcoDeck Server',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      home: ServerScreen(
        server: _server,
        themeMode: _themeMode,
        onThemeModeChanged: _saveThemeMode,
      ),
    );
  }
}
