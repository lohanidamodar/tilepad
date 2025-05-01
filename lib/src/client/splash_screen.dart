import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  String _statusMessage = 'Initializing...';

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
    setState(() {
      _statusMessage = 'Loading saved connections...';
    });

    final defaultServer =
        ref.read(providers.serverConnectionsProvider.notifier).defaultServer;

    if (defaultServer == null) {
      setState(() {
        _statusMessage = 'No default server set';
      });

      // Wait a moment so user can see the message
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder:
                (context) => const ButtonsScreen(showNoConnectionMessage: true),
          ),
        );
      }
      return;
    }

    try {
      setState(() {
        _statusMessage = 'Connecting to ${defaultServer.name}...';
      });
      debugPrint(
        'Attempting to connect to server: ${defaultServer.name} (${defaultServer.address})',
      );
    } catch (_) {
      // No server found with this ID
      setState(() {
        _statusMessage = 'Default server not found';
      });
      debugPrint(
        'Server with ID ${defaultServer.id} not found in saved connections',
      );

      // Wait a moment so user can see the message
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder:
                (context) => const ButtonsScreen(showNoConnectionMessage: true),
          ),
        );
      }
      return;
    }

    // Try to connect to the default server
    final connectionNotifier = ref.read(
      providers.connectionStateProvider.notifier,
    );

    // Ensure any previous connection is properly closed
    await connectionNotifier.disconnect();

    // Now attempt to connect
    final success = await connectionNotifier.connect(defaultServer);
    debugPrint('Connection attempt result: $success');

    if (success && mounted) {
      setState(() {
        _statusMessage = 'Connected successfully';
      });

      // Request buttons immediately after connection
      connectionNotifier.requestButtons();

      // If connection successful, navigate to buttons screen as the home screen
      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ButtonsScreen()),
        );
      }
      return;
    } else {
      setState(() {
        _statusMessage = 'Connection failed';
      });
      debugPrint('Failed to connect to default server');

      // Wait a moment so user can see the message
      await Future.delayed(const Duration(seconds: 1));
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
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
