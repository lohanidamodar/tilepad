import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'server.dart';
import 'server_screen.dart';
import '../utils/system_tray_manager.dart';
import '../design/design.dart';

/// Main entry point for the server app
void main(List<String> args) async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // `--hidden` is what the launch-at-login entry passes so the app starts
  // minimized to the tray instead of opening its window over the desktop.
  final startHidden = args.contains('--hidden');

  // Initialize window manager and the tray icon. Window-close events are
  // handled there too (close hides to the tray instead of quitting).
  await SystemTrayManager().initSystemTray(startHidden: startHidden);

  // Run the app
  runApp(const ProviderScope(child: TilepadServerApp()));
}

/// The Tilepad server application
class TilepadServerApp extends ConsumerStatefulWidget {
  /// Creates a new Tilepad server app
  const TilepadServerApp({super.key});

  @override
  ConsumerState<TilepadServerApp> createState() => _TilepadServerAppState();
}

class _TilepadServerAppState extends ConsumerState<TilepadServerApp> {
  final _server = TilepadServer();
  final _trayManager = SystemTrayManager();

  @override
  void initState() {
    super.initState();
    // Give the tray its live status menu (start/stop/restart, address, ...).
    _trayManager.attachServer(_server);
  }

  @override
  void dispose() {
    _trayManager.detachServer();
    _server.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(personalizationProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tilepad Server',
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
