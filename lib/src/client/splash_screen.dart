import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marco_deck/src/models/server_connection.dart';

import 'buttons_screen.dart';
import 'client_providers.dart' as providers;

/// Splash screen that handles automatic connection to the default server
class SplashScreen extends ConsumerStatefulWidget {
  /// Creates a new splash screen
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Delay initialization until after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    if (_initialized) return;
    _initialized = true;

    // Wait for the server connections to load
    await Future.delayed(const Duration(milliseconds: 500));

    // Get the default server ID using the provider
    final defaultServerId = ref.read(providers.defaultServerIdProvider);
    final serverConnections = ref.read(providers.serverConnectionsProvider);

    // Find the default server by ID
    ServerConnection? defaultServer;
    if (defaultServerId != null) {
      try {
        defaultServer = serverConnections.firstWhere(
          (conn) => conn.id == defaultServerId,
        );
      } catch (_) {
        // No server found with this ID
        defaultServer = null;
      }
    }

    if (defaultServer != null) {
      // Try to connect to the default server
      final connectionNotifier = ref.read(
        providers.connectionStateProvider.notifier,
      );
      final success = await connectionNotifier.connect(defaultServer);

      if (success && mounted) {
        // If connection successful, navigate to buttons screen as the home screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ButtonsScreen()),
        );
        return;
      }
    }

    // If no default server or connection failed, still go to buttons screen
    // but it will show a disconnected state with options to connect
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (context) => const ButtonsScreen(showNoConnectionMessage: true),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo
            Image.asset(
              'assets/logo.png',
              height: 120,
              errorBuilder:
                  (context, error, stackTrace) =>
                      const Icon(Icons.devices, size: 100, color: Colors.blue),
            ),
            const SizedBox(height: 32),
            const Text(
              'MarcoDeck',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
