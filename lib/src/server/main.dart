import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'server.dart';
import 'server_screen.dart';
import '../utils/system_tray_manager.dart';
import '../design/design.dart';

/// Main entry point for the server app
void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager
  await SystemTrayManager().initSystemTray();

  // Run the app
  runApp(const ProviderScope(child: MarcoDeckServerApp()));
}

/// The MarcoDeck server application
class MarcoDeckServerApp extends ConsumerStatefulWidget {
  /// Creates a new MarcoDeck server app
  const MarcoDeckServerApp({super.key});

  @override
  ConsumerState<MarcoDeckServerApp> createState() => _MarcoDeckServerAppState();
}

class _MarcoDeckServerAppState extends ConsumerState<MarcoDeckServerApp>
    with WindowListener {
  final _server = MarcoServer();
  final _trayManager = SystemTrayManager();

  @override
  void initState() {
    super.initState();
    // Register window manager listener
    windowManager.addListener(this);
    // Give the tray its live status menu (start/stop/restart, address, ...).
    _trayManager.attachServer(_server);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _trayManager.detachServer();
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
    final p = ref.watch(personalizationProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MarcoDeck Server',
      theme: buildAppTheme(
        brightness: Brightness.light,
        accent: p.accent,
        density: p.density,
      ),
      darkTheme: buildAppTheme(
        brightness: Brightness.dark,
        accent: p.accent,
        density: p.density,
      ),
      themeMode: p.themeMode,
      home: ServerScreen(server: _server),
    );
  }
}
