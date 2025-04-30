import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'client.dart';
import 'connection_screen.dart';
import 'buttons_screen.dart';

/// Main entry point for the client app
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait orientation for the client app
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MarcoDeckClientApp());
}

/// The MarcoDeck client application
class MarcoDeckClientApp extends StatefulWidget {
  /// Creates a new MarcoDeck client app
  const MarcoDeckClientApp({super.key});

  @override
  State<MarcoDeckClientApp> createState() => _MarcoDeckClientAppState();
}

class _MarcoDeckClientAppState extends State<MarcoDeckClientApp> {
  final _client = MarcoClient();
  bool _isConnected = false;

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MarcoDeck Client',
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
      home:
          _isConnected
              ? ButtonsScreen(client: _client)
              : ConnectionScreen(
                client: _client,
                onConnected: () {
                  setState(() {
                    _isConnected = true;
                  });
                },
              ),
    );
  }
}
