import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'client_providers.dart';
import 'button_grid.dart';

/// Screen for displaying and interacting with buttons
class ButtonsScreen extends ConsumerStatefulWidget {
  /// Creates a buttons screen
  const ButtonsScreen({super.key});

  @override
  ConsumerState<ButtonsScreen> createState() => _ButtonsScreenState();
}

class _ButtonsScreenState extends ConsumerState<ButtonsScreen> {
  bool _showResult = false;

  @override
  void initState() {
    super.initState();

    // Request buttons from server when screen is first shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(connectionStateProvider.notifier).requestButtons();
    });
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionStateProvider);
    final buttons = ref.watch(buttonsProvider);
    final commandResult = ref.watch(commandResultProvider);

    final isConnected = connectionState.status == ConnectionStatus.connected;

    return Scaffold(
      appBar: AppBar(
        title: Text(connectionState.connection?.name ?? 'MarcoDeck'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(connectionStateProvider.notifier).requestButtons();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Buttons refreshed'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 1),
                ),
              );
            },
            tooltip: 'Refresh buttons',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(connectionStateProvider.notifier).disconnect();
              Navigator.of(context).pop();
            },
            tooltip: 'Disconnect',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Button grid
          ButtonGrid(
            buttons: buttons,
            onButtonPressed: (buttonId) {
              // Press the button via the connection state notifier
              ref.read(connectionStateProvider.notifier).pressButton(buttonId);

              // Clear any previous results when a button is pressed
              setState(() {
                _showResult = false;
              });
            },
          ),

          // Connection status indicator
          if (!isConnected)
            Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    connectionState.status == ConnectionStatus.connecting
                        ? 'Connecting...'
                        : 'Disconnected',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (connectionState.status == ConnectionStatus.error)
                        ElevatedButton(
                          onPressed: () {
                            ref
                                .read(connectionStateProvider.notifier)
                                .refreshConnection();
                          },
                          child: const Text('Retry'),
                        ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Back'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Command result display
          if (_showResult && commandResult != null ||
              commandResult != null && !_showResult)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black87,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Result',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              _showResult = false;
                            });
                          },
                          iconSize: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: SingleChildScrollView(
                        child: Text(
                          commandResult.success
                              ? commandResult.output
                              : 'Error: ${commandResult.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
