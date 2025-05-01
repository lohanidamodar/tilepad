import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/server_connection.dart';
import 'client_providers.dart';
import 'button_grid.dart';
import 'server_list_screen.dart';
import 'connection_screen.dart';

/// Screen for displaying and interacting with buttons
class ButtonsScreen extends ConsumerStatefulWidget {
  /// Creates a buttons screen
  ///
  /// If [showNoConnectionMessage] is true, a message will be shown prompting the user
  /// to connect to a server if no connection is active
  const ButtonsScreen({super.key, this.showNoConnectionMessage = false});

  /// Whether to show a message prompting the user to connect to a server
  final bool showNoConnectionMessage;

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
      final connectionState = ref.read(connectionStateProvider);
      if (connectionState.status == ConnectionStatus.connected) {
        ref.read(connectionStateProvider.notifier).requestButtons();
      }
    });
  }

  void _showServerManager(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const ServerListScreen()));
  }

  void _showAddServerDialog(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const ConnectionScreen()));
  }

  void _connectToDefault(BuildContext context) async {
    // Get the default server ID using the provider
    final defaultServerId = ref.read(defaultServerIdProvider);
    final serverConnections = ref.read(serverConnectionsProvider);

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
      final connectionNotifier = ref.read(connectionStateProvider.notifier);
      final success = await connectionNotifier.connect(defaultServer);

      if (success) {
        // Request buttons from server after successful connection
        connectionNotifier.requestButtons();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No default server set'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
          if (isConnected)
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
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'servers':
                  _showServerManager(context);
                  break;
                case 'add_server':
                  _showAddServerDialog(context);
                  break;
                case 'connect_default':
                  _connectToDefault(context);
                  break;
                case 'disconnect':
                  ref.read(connectionStateProvider.notifier).disconnect();
                  break;
              }
            },
            itemBuilder:
                (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'servers',
                    child: ListTile(
                      leading: Icon(Icons.computer),
                      title: Text('Manage Servers'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'add_server',
                    child: ListTile(
                      leading: Icon(Icons.add_circle_outline),
                      title: Text('Add New Server'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  if (!isConnected)
                    const PopupMenuItem<String>(
                      value: 'connect_default',
                      child: ListTile(
                        leading: Icon(Icons.link),
                        title: Text('Connect to Default'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  if (isConnected)
                    const PopupMenuItem<String>(
                      value: 'disconnect',
                      child: ListTile(
                        leading: Icon(Icons.link_off),
                        title: Text('Disconnect'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Button grid or no connection message
          if (isConnected)
            ButtonGrid(
              buttons: buttons,
              onButtonPressed: (buttonId) {
                // Press the button via the connection state notifier
                ref
                    .read(connectionStateProvider.notifier)
                    .pressButton(buttonId);

                // Clear any previous results when a button is pressed
                setState(() {
                  _showResult = false;
                });
              },
            )
          else
            _buildNoConnectionView(context),

          // Connection status indicator for connecting/error state
          if (connectionState.status == ConnectionStatus.connecting ||
              connectionState.status == ConnectionStatus.error)
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
                        : 'Connection Error',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  if (connectionState.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        connectionState.errorMessage!,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
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
                        onPressed: () {
                          ref
                              .read(connectionStateProvider.notifier)
                              .resetErrorState();
                        },
                        child: const Text('Dismiss'),
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

  Widget _buildNoConnectionView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/logo.png',
            height: 120,
            errorBuilder:
                (context, error, stackTrace) =>
                    const Icon(Icons.devices, size: 100, color: Colors.blue),
          ),
          const SizedBox(height: 24),
          Text(
            'Not Connected to a Server',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Text(
            'Connect to a server to view and use your buttons',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.computer),
            label: const Text('Choose Server'),
            onPressed: () => _showServerManager(context),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add New Server'),
            onPressed: () => _showAddServerDialog(context),
          ),
          if (ref.read(defaultServerIdProvider) != null) ...[
            const SizedBox(height: 24),
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Connect to Default Server'),
              onPressed: () => _connectToDefault(context),
            ),
          ],
        ],
      ),
    );
  }
}
