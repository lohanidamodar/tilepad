import 'package:flutter/material.dart';

import 'server.dart';
import 'server_screen.dart';

/// Main entry point for the server app
void main() {
  runApp(const MarcoDeckServerApp());
}

/// The MarcoDeck server application
class MarcoDeckServerApp extends StatefulWidget {
  /// Creates a new MarcoDeck server app
  const MarcoDeckServerApp({super.key});

  @override
  State<MarcoDeckServerApp> createState() => _MarcoDeckServerAppState();
}

class _MarcoDeckServerAppState extends State<MarcoDeckServerApp> {
  final _server = MarcoServer();

  @override
  void dispose() {
    _server.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
