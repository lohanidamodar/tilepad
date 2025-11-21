import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/server_connection.dart';
import '../utils/theme.dart';
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
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Servers'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Theme mode selector
          ThemeModeSelector(
            currentThemeMode: themeMode,
            onThemeModeChanged: (mode) {
              ref.read(themeModeProvider.notifier).setThemeMode(mode);
            },
          ),
        ],
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const ConnectionScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Server'),
      ),
    );
  }

  Widget _buildConnectionStatusBar(
    BuildContext context,
    providers.ConnectionState connectionState,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    Color backgroundColor;
    Color foregroundColor;
    String statusText;
    IconData iconData;

    switch (connectionState.status) {
      case providers.ConnectionStatus.connected:
        backgroundColor = colorScheme.primaryContainer;
        foregroundColor = colorScheme.onPrimaryContainer;
        statusText = 'Connected to ${connectionState.connection?.name}';
        iconData = Icons.check_circle;
        break;
      case providers.ConnectionStatus.connecting:
        backgroundColor = colorScheme.tertiaryContainer;
        foregroundColor = colorScheme.onTertiaryContainer;
        statusText = 'Connecting to ${connectionState.connection?.name}...';
        iconData = Icons.pending;
        break;
      case providers.ConnectionStatus.error:
        backgroundColor = colorScheme.errorContainer;
        foregroundColor = colorScheme.onErrorContainer;
        statusText = connectionState.errorMessage ?? 'Connection error';
        iconData = Icons.error;
        break;
      default:
        backgroundColor = colorScheme.surface;
        foregroundColor = colorScheme.onSurfaceVariant;
        statusText = 'Not connected';
        iconData = Icons.info;
    }

    return Material(
      color: backgroundColor,
      elevation: AppTheme.elevationMedium,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppTheme.spaceMedium,
          horizontal: AppTheme.spaceLarge,
        ),
        child: Row(
          children: [
            Icon(iconData, color: foregroundColor, size: 20),
            const SizedBox(width: AppTheme.spaceMedium),
            Expanded(
              child: Text(
                statusText,
                style: TextStyle(
                  color: foregroundColor,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (connectionState.status == providers.ConnectionStatus.connected)
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary.withAlpha(50),
                  foregroundColor: foregroundColor,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMedium,
                  ),
                ),
                onPressed: () {
                  final notifier = ProviderScope.containerOf(
                    context,
                  ).read(providers.connectionStateProvider.notifier);
                  notifier.disconnect();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.link_off, size: 16),
                    const SizedBox(width: AppTheme.spaceXSmall),
                    const Text('Disconnect'),
                  ],
                ),
              ),
            if (connectionState.status == providers.ConnectionStatus.connecting)
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.tertiary.withAlpha(50),
                  foregroundColor: foregroundColor,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMedium,
                  ),
                ),
                onPressed: () {
                  final notifier = ProviderScope.containerOf(
                    context,
                  ).read(providers.connectionStateProvider.notifier);
                  notifier.cancelConnection();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cancel, size: 16),
                    const SizedBox(width: AppTheme.spaceXSmall),
                    const Text('Cancel'),
                  ],
                ),
              ),
            if (connectionState.status == providers.ConnectionStatus.error)
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error.withAlpha(50),
                  foregroundColor: foregroundColor,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMedium,
                  ),
                ),
                onPressed: () {
                  final notifier = ProviderScope.containerOf(
                    context,
                  ).read(providers.connectionStateProvider.notifier);
                  notifier.resetErrorState();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, size: 16),
                    const SizedBox(width: AppTheme.spaceXSmall),
                    const Text('Dismiss'),
                  ],
                ),
              ),
            if (connectionState.status == providers.ConnectionStatus.connected)
              const SizedBox(width: AppTheme.spaceSmall),
            if (connectionState.status == providers.ConnectionStatus.connected)
              IconButton.filled(
                icon: const Icon(Icons.open_in_new, size: 18),
                tooltip: 'Go to Buttons',
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer(
      builder: (context, ref, child) {
        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.all(AppTheme.spaceXLarge),
            margin: const EdgeInsets.all(AppTheme.spaceXLarge),
            decoration: BoxDecoration(
              color: colorScheme.surface.withAlpha(127),
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(color: colorScheme.outlineVariant, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withAlpha(30),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(AppTheme.spaceXLarge),
                  child: Image.asset(
                    'assets/logo.png',
                    height: 80,
                    errorBuilder:
                        (context, error, stackTrace) => Icon(
                          Icons.devices,
                          size: 80,
                          color: colorScheme.primary,
                        ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'No Saved Servers',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Add a server to discover or enter manually',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ConnectionScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Server'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildServerList(
    BuildContext context,
    WidgetRef ref,
    List<ServerConnection> connections,
  ) {
    final connectionState = ref.watch(providers.connectionStateProvider);
    final defaultServerId = ref.watch(providers.defaultServerIdProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80, top: 8),
      itemCount: connections.length,
      itemBuilder: (context, index) {
        final connection = connections[index];
        final dateFormat = DateFormat('MMM d, yyyy • h:mm a');

        final isConnected =
            connectionState.status == providers.ConnectionStatus.connected &&
            connectionState.connection?.id == connection.id;

        final isDefault = connection.id == defaultServerId;

        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceLarge,
            vertical: AppTheme.spaceSmall,
          ),
          clipBehavior: Clip.antiAlias,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            side:
                isConnected
                    ? BorderSide(color: colorScheme.primary, width: 2)
                    : BorderSide.none,
          ),
          child: InkWell(
            onTap: () {
              _connectToServer(context, ref, connection);
            },
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceXSmall),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with server status
                  Container(
                    decoration: BoxDecoration(
                      color:
                          isConnected
                              ? colorScheme.primaryContainer.withAlpha(127)
                              : null,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceLarge,
                      vertical: AppTheme.spaceSmall,
                    ),
                    child: Row(
                      children: [
                        // Server icon with connection indicator
                        Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    isConnected
                                        ? colorScheme.primary.withAlpha(30)
                                        : colorScheme.surface,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.computer,
                                color:
                                    isConnected
                                        ? colorScheme.primary
                                        : colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (isConnected)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          Theme.of(
                                            context,
                                          ).scaffoldBackgroundColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.check,
                                      size: 10,
                                      color: colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 16),

                        // Server name and indicators
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      connection.name,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            isConnected
                                                ? colorScheme.primary
                                                : colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  if (isDefault)
                                    Tooltip(
                                      message: 'Default Server',
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.tertiaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.star,
                                              size: 14,
                                              color:
                                                  colorScheme
                                                      .onTertiaryContainer,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Default',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    colorScheme
                                                        .onTertiaryContainer,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                connection.address,
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Actions button
                        IconButton(
                          icon: Icon(
                            Icons.more_vert,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () {
                            _showServerOptions(context, ref, connection);
                          },
                        ),
                      ],
                    ),
                  ),

                  // Footer with connection status and last connected time
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Last connected: ${dateFormat.format(connection.lastConnected)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        if (isConnected)
                          FilledButton.icon(
                            icon: const Icon(Icons.open_in_new, size: 14),
                            label: const Text('Open'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                            ),
                          )
                        else
                          OutlinedButton.icon(
                            icon: const Icon(Icons.link, size: 14),
                            label: const Text('Connect'),
                            onPressed: () {
                              _connectToServer(context, ref, connection);
                            },
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          margin: const EdgeInsets.all(8),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sheet handle and header
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withAlpha(120),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.computer,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              connection.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              connection.address,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),

                // Actions
                ListTile(
                  leading: Icon(Icons.edit, color: colorScheme.primary),
                  title: const Text('Edit Server'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (context) => ConnectionScreen(
                              existingConnection: connection,
                            ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.link, color: colorScheme.primary),
                  title: const Text('Connect'),
                  onTap: () {
                    Navigator.pop(context);
                    _connectToServer(context, ref, connection);
                  },
                ),
                ListTile(
                  leading: Icon(
                    isDefault ? Icons.star : Icons.star_border,
                    color:
                        isDefault ? colorScheme.tertiary : colorScheme.primary,
                  ),
                  title: Text(
                    isDefault ? 'Remove as Default' : 'Set as Default',
                  ),
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
                        backgroundColor: colorScheme.primaryContainer,
                        showCloseIcon: true,
                        closeIconColor: colorScheme.onPrimaryContainer,
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Icon(Icons.delete, color: colorScheme.error),
                  title: Text(
                    'Delete Server',
                    style: TextStyle(color: colorScheme.error),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteServer(context, ref, connection);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
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
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            color: colorScheme.error,
            size: 32,
          ),
          title: const Text('Delete Server'),
          content: Text(
            'Are you sure you want to delete "${connection.name}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
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

                // Show confirmation
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Server "${connection.name}" has been deleted',
                    ),
                    behavior: SnackBarBehavior.floating,
                    showCloseIcon: true,
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.errorContainer,
                foregroundColor: colorScheme.onErrorContainer,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
