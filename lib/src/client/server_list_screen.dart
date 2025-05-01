import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/server_connection.dart';
import 'buttons_screen.dart';
import 'client_providers.dart' as providers;
import 'connection_screen.dart';

/// Screen for managing server connections
class ServerListScreen extends ConsumerWidget {
  /// Creates a new server management screen
  const ServerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connections = ref.watch(providers.serverConnectionsProvider);
    final connectionState = ref.watch(providers.connectionStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Servers'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Connection status bar
          if (connectionState.status != providers.ConnectionStatus.disconnected)
            _buildConnectionStatusBar(context, connectionState),

          // Server list
          Expanded(
            child:
                connections.isEmpty
                    ? _buildEmptyState(context)
                    : _buildServerList(context, ref, connections),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const ConnectionScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildConnectionStatusBar(
    BuildContext context,
    providers.ConnectionState connectionState,
  ) {
    Color backgroundColor;
    String statusText;
    IconData iconData;

    switch (connectionState.status) {
      case providers.ConnectionStatus.connected:
        backgroundColor = Colors.green;
        statusText = 'Connected to ${connectionState.connection?.name}';
        iconData = Icons.check_circle;
        break;
      case providers.ConnectionStatus.connecting:
        backgroundColor = Colors.orange;
        statusText = 'Connecting to ${connectionState.connection?.name}...';
        iconData = Icons.pending;
        break;
      case providers.ConnectionStatus.error:
        backgroundColor = Colors.red;
        statusText = connectionState.errorMessage ?? 'Connection error';
        iconData = Icons.error;
        break;
      default:
        backgroundColor = Colors.grey;
        statusText = 'Not connected';
        iconData = Icons.info;
    }

    return Material(
      color: backgroundColor,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Row(
          children: [
            Icon(iconData, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                statusText,
                style: const TextStyle(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (connectionState.status == providers.ConnectionStatus.connected)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: () {
                  final notifier = ProviderScope.containerOf(
                    context,
                  ).read(providers.connectionStateProvider.notifier);
                  notifier.disconnect();
                },
                icon: const Icon(Icons.link_off, size: 16),
                label: const Text('Disconnect'),
              ),
            if (connectionState.status == providers.ConnectionStatus.connecting)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: () {
                  final notifier = ProviderScope.containerOf(
                    context,
                  ).read(providers.connectionStateProvider.notifier);
                  notifier.cancelConnection();
                },
                icon: const Icon(Icons.cancel, size: 16),
                label: const Text('Cancel'),
              ),
            if (connectionState.status == providers.ConnectionStatus.error)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: () {
                  final notifier = ProviderScope.containerOf(
                    context,
                  ).read(providers.connectionStateProvider.notifier);
                  notifier.resetErrorState();
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Dismiss'),
              ),
            if (connectionState.status == providers.ConnectionStatus.connected)
              IconButton(
                icon: const Icon(Icons.open_in_new, color: Colors.white),
                tooltip: 'Go to Buttons',
                onPressed: () {
                  // Navigate back to ButtonsScreen
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/logo.png',
            height: 100,
            errorBuilder:
                (context, error, stackTrace) =>
                    const Icon(Icons.devices, size: 80, color: Colors.blueGrey),
          ),
          const SizedBox(height: 24),
          Text(
            'No Saved Servers',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add a server',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildServerList(
    BuildContext context,
    WidgetRef ref,
    List<ServerConnection> connections,
  ) {
    final connectionState = ref.watch(providers.connectionStateProvider);
    final defaultServerId = ref.watch(providers.defaultServerIdProvider);

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: connections.length,
      itemBuilder: (context, index) {
        final connection = connections[index];
        final dateFormat = DateFormat('MMM d, h:mm a');

        final isConnected =
            connectionState.status == providers.ConnectionStatus.connected &&
            connectionState.connection?.id == connection.id;

        final isDefault = connection.id == defaultServerId;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: Icon(
              Icons.computer,
              color: isConnected ? Colors.green : null,
            ),
            title: Row(
              children: [
                Expanded(child: Text(connection.name)),
                if (isDefault)
                  const Icon(Icons.star, size: 18, color: Colors.amber),
              ],
            ),
            subtitle: Text(
              'Last connected: ${dateFormat.format(connection.lastConnected)}\n${connection.address}',
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isConnected)
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),

                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    _showServerOptions(context, ref, connection);
                  },
                ),
              ],
            ),
            onTap: () {
              _connectToServer(context, ref, connection);
            },
          ),
        );
      },
    );
  }

  void _connectToServer(
    BuildContext context,
    WidgetRef ref,
    ServerConnection connection,
  ) async {
    final notifier = ref.read(providers.connectionStateProvider.notifier);

    final success = await notifier.connect(connection);

    if (success && context.mounted) {
      // On success, return to the ButtonsScreen
      Navigator.of(context).pop();
    }
  }

  void _showServerOptions(
    BuildContext context,
    WidgetRef ref,
    ServerConnection connection,
  ) {
    // Check if this server is the default
    final isDefault =
        ref.read(providers.defaultServerIdProvider) == connection.id;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Server'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (context) =>
                              ConnectionScreen(existingConnection: connection),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Connect'),
                onTap: () {
                  Navigator.pop(context);
                  _connectToServer(context, ref, connection);
                },
              ),
              ListTile(
                leading: Icon(
                  isDefault ? Icons.star : Icons.star_border,
                  color: isDefault ? Colors.amber : null,
                ),
                title: Text(isDefault ? 'Remove as Default' : 'Set as Default'),
                onTap: () {
                  Navigator.pop(context);

                  // Toggle default status
                  final connectionsNotifier = ref.read(
                    providers.serverConnectionsProvider.notifier,
                  );
                  connectionsNotifier.setDefaultServer(
                    isDefault ? null : connection.id,
                  );

                  // Show confirmation
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isDefault
                            ? 'Default server removed'
                            : '${connection.name} set as default server',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteServer(context, ref, connection);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteServer(
    BuildContext context,
    WidgetRef ref,
    ServerConnection connection,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Server'),
          content: Text(
            'Are you sure you want to delete "${connection.name}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                ref
                    .read(providers.serverConnectionsProvider.notifier)
                    .removeConnection(connection.id);

                // If this server is currently connected, disconnect
                final connectionState = ref.read(
                  providers.connectionStateProvider,
                );
                if (connectionState.connection?.id == connection.id) {
                  ref
                      .read(providers.connectionStateProvider.notifier)
                      .disconnect();
                }

                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
