import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'server.dart';
import 'server_screen.dart';
import '../utils/system_tray_manager.dart';

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

  @override
  void initState() {
    super.initState();
    // Register window manager listener
    windowManager.addListener(this);
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4285F4)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4285F4),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: ServerScreen(server: _server),
    );
  }
}
