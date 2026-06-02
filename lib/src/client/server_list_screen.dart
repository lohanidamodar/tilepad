import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../design/design.dart';
import '../models/server_connection.dart';
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
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Appearance',
            onPressed: () => _showAppearanceSheet(context),
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
            child: connections.isEmpty
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

  /// Opens the shared appearance picker (theme mode, accent, density).
  void _showAppearanceSheet(BuildContext context) {
    final t = context.tokens;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            t.space.xl,
            t.space.sm,
            t.space.xl,
            t.space.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Appearance',
                  style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: t.space.lg),
              const PersonalizationPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatusBar(
    BuildContext context,
    providers.ConnectionState connectionState,
  ) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    Color dotColor;
    String statusText;

    switch (connectionState.status) {
      case providers.ConnectionStatus.connected:
        dotColor = tokens.color.success;
        statusText = 'Connected to ${connectionState.connection?.name}';
        break;
      case providers.ConnectionStatus.connecting:
        dotColor = tokens.color.warning;
        statusText = 'Connecting to ${connectionState.connection?.name}...';
        break;
      case providers.ConnectionStatus.error:
        dotColor = tokens.color.danger;
        statusText = connectionState.errorMessage ?? 'Connection error';
        break;
      default:
        dotColor = tokens.color.textMuted;
        statusText = 'Not connected';
    }

    return Material(
      color: tokens.color.surfaceSubtle,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: tokens.color.border,
              width: tokens.border.hairline,
            ),
          ),
        ),
        padding: EdgeInsets.symmetric(
          vertical: tokens.space.md,
          horizontal: tokens.space.lg,
        ),
        child: Row(
          children: [
            Container(
              width: tokens.space.sm,
              height: tokens.space.sm,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
              ),
            ),
            SizedBox(width: tokens.space.md),
            Expanded(
              child: Text(
                statusText,
                style: textTheme.bodyMedium?.copyWith(
                  color: tokens.color.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (connectionState.status == providers.ConnectionStatus.connected)
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  final notifier = ProviderScope.containerOf(
                    context,
                  ).read(providers.connectionStateProvider.notifier);
                  notifier.disconnect();
                },
                child: const Text('Disconnect'),
              ),
            if (connectionState.status == providers.ConnectionStatus.connecting)
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  final notifier = ProviderScope.containerOf(
                    context,
                  ).read(providers.connectionStateProvider.notifier);
                  notifier.cancelConnection();
                },
                child: const Text('Cancel'),
              ),
            if (connectionState.status == providers.ConnectionStatus.error)
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  final notifier = ProviderScope.containerOf(
                    context,
                  ).read(providers.connectionStateProvider.notifier);
                  notifier.resetErrorState();
                },
                child: const Text('Dismiss'),
              ),
            if (connectionState.status == providers.ConnectionStatus.connected)
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  // Navigate back to ButtonsScreen
                  Navigator.of(context).pop();
                },
                child: const Text('Open'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Consumer(
      builder: (context, ref, child) {
        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: EdgeInsets.all(tokens.space.xl),
            margin: EdgeInsets.all(tokens.space.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.dns_outlined,
                  size: tokens.space.huge,
                  color: tokens.color.textMuted,
                ),
                SizedBox(height: tokens.space.xxxl),
                Text(
                  'No Saved Servers',
                  style: textTheme.titleLarge?.copyWith(
                    color: tokens.color.textSecondary,
                  ),
                ),
                SizedBox(height: tokens.space.md),
                Text(
                  'Add a server to discover or enter manually',
                  style: textTheme.bodyMedium?.copyWith(
                    color: tokens.color.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: tokens.space.xxxl),
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
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return ListView.builder(
      padding: EdgeInsets.only(
        bottom: tokens.space.huge + tokens.space.xxxl,
        top: tokens.space.sm,
      ),
      itemCount: connections.length,
      itemBuilder: (context, index) {
        final connection = connections[index];
        final dateFormat = DateFormat('MMM d, yyyy • h:mm a');

        final isConnected =
            connectionState.status == providers.ConnectionStatus.connected &&
            connectionState.connection?.id == connection.id;

        final isDefault = connection.id == defaultServerId;

        return Card(
          margin: EdgeInsets.symmetric(
            horizontal: tokens.space.lg,
            vertical: tokens.space.sm,
          ),
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          color: tokens.color.surfaceRaised,
          shape: RoundedRectangleBorder(
            borderRadius: tokens.radius.brMd,
            side: isConnected
                ? BorderSide(
                    color: tokens.color.accent,
                    width: tokens.border.strong,
                  )
                : BorderSide(
                    color: tokens.color.border,
                    width: tokens.border.hairline,
                  ),
          ),
          child: InkWell(
            onTap: () {
              _connectToServer(context, ref, connection);
            },
            child: Padding(
              padding: EdgeInsets.all(tokens.space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with server status
                  Row(
                    children: [
                      // Flat monochrome server icon with a small status dot.
                      Icon(
                        Icons.dns_outlined,
                        size: tokens.icon.xl,
                        color: isConnected
                            ? tokens.color.accent
                            : tokens.color.textSecondary,
                      ),
                      SizedBox(width: tokens.space.lg),

                      // Server name and indicators
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    connection.name,
                                    style: textTheme.titleMedium?.copyWith(
                                      color: isConnected
                                          ? tokens.color.accent
                                          : tokens.color.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isConnected) ...[
                                  SizedBox(width: tokens.space.sm),
                                  Container(
                                    width: tokens.space.sm,
                                    height: tokens.space.sm,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: tokens.color.success,
                                    ),
                                  ),
                                ],
                                if (isDefault) ...[
                                  SizedBox(width: tokens.space.sm),
                                  Tooltip(
                                    message: 'Default Server',
                                    child: Icon(
                                      Icons.star_outline,
                                      size: tokens.icon.sm,
                                      color: tokens.color.textMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            SizedBox(height: tokens.space.xs),
                            Text(
                              connection.address,
                              style: AppTypography.mono(
                                fontSize: tokens.typeScale.bodySm,
                                color: tokens.color.textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Actions button
                      IconButton(
                        icon: Icon(
                          Icons.more_vert,
                          color: tokens.color.textSecondary,
                        ),
                        onPressed: () {
                          _showServerOptions(context, ref, connection);
                        },
                      ),
                    ],
                  ),

                  SizedBox(height: tokens.space.lg),
                  Divider(
                    height: tokens.border.hairline,
                    color: tokens.color.border,
                  ),
                  SizedBox(height: tokens.space.md),

                  // Footer with connection status and last connected time
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Last connected ${dateFormat.format(connection.lastConnected)}',
                          style: AppTypography.mono(
                            fontSize: tokens.typeScale.labelSm,
                            color: tokens.color.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: tokens.space.sm),
                      if (isConnected)
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('Open'),
                        )
                      else
                        TextButton(
                          onPressed: () {
                            _connectToServer(context, ref, connection);
                          },
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('Connect'),
                        ),
                    ],
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
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: tokens.color.surfaceRaised,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(tokens.radius.lg),
            ),
          ),
          margin: EdgeInsets.all(tokens.space.sm),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sheet handle and header
                Container(
                  width: tokens.space.huge - tokens.space.sm,
                  height: tokens.space.xs,
                  margin: EdgeInsets.only(top: tokens.space.sm),
                  decoration: BoxDecoration(
                    color: tokens.color.border,
                    borderRadius: tokens.radius.brXs,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(tokens.space.lg),
                  child: Row(
                    children: [
                      Icon(
                        Icons.dns_outlined,
                        size: tokens.icon.xl,
                        color: tokens.color.textSecondary,
                      ),
                      SizedBox(width: tokens.space.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              connection.name,
                              style: textTheme.titleMedium?.copyWith(
                                color: tokens.color.textPrimary,
                              ),
                            ),
                            Text(
                              connection.address,
                              style: AppTypography.mono(
                                color: tokens.color.textSecondary,
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
                  leading: Icon(
                    Icons.edit_outlined,
                    color: tokens.color.textSecondary,
                  ),
                  title: const Text('Edit Server'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            ConnectionScreen(existingConnection: connection),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.link,
                    color: tokens.color.textSecondary,
                  ),
                  title: const Text('Connect'),
                  onTap: () {
                    Navigator.pop(context);
                    _connectToServer(context, ref, connection);
                  },
                ),
                ListTile(
                  leading: Icon(
                    isDefault ? Icons.star : Icons.star_border,
                    color: isDefault
                        ? tokens.color.warning
                        : tokens.color.textSecondary,
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
                        backgroundColor: tokens.color.accentSubtle,
                        showCloseIcon: true,
                        closeIconColor: tokens.color.accent,
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Icon(Icons.delete, color: tokens.color.danger),
                  title: Text(
                    'Delete Server',
                    style: TextStyle(color: tokens.color.danger),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteServer(context, ref, connection);
                  },
                ),
                SizedBox(height: tokens.space.sm),
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
    final tokens = context.tokens;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            color: tokens.color.danger,
            size: tokens.space.xxxl,
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
                backgroundColor: tokens.color.dangerSubtle,
                foregroundColor: tokens.color.danger,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
