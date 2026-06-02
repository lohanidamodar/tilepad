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
    Color backgroundColor;
    Color foregroundColor;
    Color accentColor;
    String statusText;
    IconData iconData;

    switch (connectionState.status) {
      case providers.ConnectionStatus.connected:
        backgroundColor = tokens.color.successSubtle;
        foregroundColor = tokens.color.success;
        accentColor = tokens.color.success;
        statusText = 'Connected to ${connectionState.connection?.name}';
        iconData = Icons.check_circle;
        break;
      case providers.ConnectionStatus.connecting:
        backgroundColor = tokens.color.warningSubtle;
        foregroundColor = tokens.color.warning;
        accentColor = tokens.color.warning;
        statusText = 'Connecting to ${connectionState.connection?.name}...';
        iconData = Icons.pending;
        break;
      case providers.ConnectionStatus.error:
        backgroundColor = tokens.color.dangerSubtle;
        foregroundColor = tokens.color.danger;
        accentColor = tokens.color.danger;
        statusText = connectionState.errorMessage ?? 'Connection error';
        iconData = Icons.error;
        break;
      default:
        backgroundColor = tokens.color.surface;
        foregroundColor = tokens.color.textSecondary;
        accentColor = tokens.color.accent;
        statusText = 'Not connected';
        iconData = Icons.info;
    }

    return Material(
      color: backgroundColor,
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: tokens.space.md,
          horizontal: tokens.space.lg,
        ),
        child: Row(
          children: [
            Icon(iconData, color: foregroundColor, size: tokens.icon.lg),
            SizedBox(width: tokens.space.md),
            Expanded(
              child: Text(
                statusText,
                style: textTheme.bodyMedium?.copyWith(
                  color: foregroundColor,
                  fontWeight: tokens.typeScale.wMedium,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (connectionState.status == providers.ConnectionStatus.connected)
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor.withValues(
                    alpha: tokens.opacity.subtle,
                  ),
                  foregroundColor: foregroundColor,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.symmetric(horizontal: tokens.space.md),
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
                    Icon(Icons.link_off, size: tokens.icon.sm),
                    SizedBox(width: tokens.space.xs),
                    const Text('Disconnect'),
                  ],
                ),
              ),
            if (connectionState.status == providers.ConnectionStatus.connecting)
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor.withValues(
                    alpha: tokens.opacity.subtle,
                  ),
                  foregroundColor: foregroundColor,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.symmetric(horizontal: tokens.space.md),
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
                    Icon(Icons.cancel, size: tokens.icon.sm),
                    SizedBox(width: tokens.space.xs),
                    const Text('Cancel'),
                  ],
                ),
              ),
            if (connectionState.status == providers.ConnectionStatus.error)
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor.withValues(
                    alpha: tokens.opacity.subtle,
                  ),
                  foregroundColor: foregroundColor,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.symmetric(horizontal: tokens.space.md),
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
                    Icon(Icons.refresh, size: tokens.icon.sm),
                    SizedBox(width: tokens.space.xs),
                    const Text('Dismiss'),
                  ],
                ),
              ),
            if (connectionState.status == providers.ConnectionStatus.connected)
              SizedBox(width: tokens.space.sm),
            if (connectionState.status == providers.ConnectionStatus.connected)
              IconButton.filled(
                icon: Icon(Icons.open_in_new, size: tokens.icon.md),
                tooltip: 'Go to Buttons',
                style: IconButton.styleFrom(
                  backgroundColor: tokens.color.accent,
                  foregroundColor: tokens.color.onAccent,
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
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Consumer(
      builder: (context, ref, child) {
        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: EdgeInsets.all(tokens.space.xl),
            margin: EdgeInsets.all(tokens.space.xl),
            decoration: BoxDecoration(
              color: tokens.color.surfaceRaised,
              borderRadius: tokens.radius.brLg,
              border: Border.all(
                color: tokens.color.border,
                width: tokens.border.hairline,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: tokens.color.accentSubtle,
                    shape: BoxShape.circle,
                    boxShadow: tokens.shadowSm,
                  ),
                  padding: EdgeInsets.all(tokens.space.xl),
                  child: Image.asset(
                    'assets/logo.png',
                    height: tokens.space.huge + tokens.space.xxxl,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.devices,
                      size: tokens.space.huge + tokens.space.xxxl,
                      color: tokens.color.accent,
                    ),
                  ),
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
              padding: EdgeInsets.all(tokens.space.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with server status
                  Container(
                    decoration: BoxDecoration(
                      color: isConnected ? tokens.color.accentSubtle : null,
                      borderRadius: tokens.radius.brSm,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.space.lg,
                      vertical: tokens.space.sm,
                    ),
                    child: Row(
                      children: [
                        // Server icon with connection indicator
                        Stack(
                          children: [
                            Container(
                              padding: EdgeInsets.all(tokens.space.sm),
                              decoration: BoxDecoration(
                                color: isConnected
                                    ? tokens.color.accentSubtle
                                    : tokens.color.surfaceSubtle,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.computer,
                                color: isConnected
                                    ? tokens.color.accent
                                    : tokens.color.textSecondary,
                              ),
                            ),
                            if (isConnected)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: tokens.icon.sm,
                                  height: tokens.icon.sm,
                                  decoration: BoxDecoration(
                                    color: tokens.color.accent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: tokens.color.surface,
                                      width: tokens.border.focus,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.check,
                                      size: tokens.space.sm + tokens.space.xxs,
                                      color: tokens.color.onAccent,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(width: tokens.space.lg),

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
                                      style: textTheme.titleMedium?.copyWith(
                                        color: isConnected
                                            ? tokens.color.accent
                                            : tokens.color.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (isDefault)
                                    Tooltip(
                                      message: 'Default Server',
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: tokens.space.sm,
                                          vertical: tokens.space.xs,
                                        ),
                                        decoration: BoxDecoration(
                                          color: tokens.color.warningSubtle,
                                          borderRadius: tokens.radius.brMd,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.star,
                                              size: tokens.icon.xs,
                                              color: tokens.color.warning,
                                            ),
                                            SizedBox(width: tokens.space.xs),
                                            Text(
                                              'Default',
                                              style: textTheme.labelMedium
                                                  ?.copyWith(
                                                    fontWeight:
                                                        tokens.typeScale.wBold,
                                                    color: tokens.color.warning,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: tokens.space.xs),
                              Text(
                                connection.address,
                                style: AppTypography.mono(
                                  color: tokens.color.textSecondary,
                                ),
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
                  ),

                  // Footer with connection status and last connected time
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      tokens.space.lg,
                      tokens.space.sm,
                      tokens.space.lg,
                      tokens.space.md,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: tokens.icon.xs,
                          color: tokens.color.textMuted,
                        ),
                        SizedBox(width: tokens.space.xs),
                        Text(
                          'Last connected: ${dateFormat.format(connection.lastConnected)}',
                          style: textTheme.labelMedium?.copyWith(
                            color: tokens.color.textMuted,
                          ),
                        ),
                        const Spacer(),
                        if (isConnected)
                          FilledButton.icon(
                            icon: Icon(Icons.open_in_new, size: tokens.icon.xs),
                            label: const Text('Open'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.symmetric(
                                horizontal: tokens.space.md,
                                vertical: tokens.space.xs,
                              ),
                            ),
                          )
                        else
                          OutlinedButton.icon(
                            icon: Icon(Icons.link, size: tokens.icon.xs),
                            label: const Text('Connect'),
                            onPressed: () {
                              _connectToServer(context, ref, connection);
                            },
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.symmetric(
                                horizontal: tokens.space.md,
                                vertical: tokens.space.xs,
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
                      Container(
                        padding: EdgeInsets.all(tokens.space.sm),
                        decoration: BoxDecoration(
                          color: tokens.color.accentSubtle,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.computer, color: tokens.color.accent),
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
                  leading: Icon(Icons.edit, color: tokens.color.accent),
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
                  leading: Icon(Icons.link, color: tokens.color.accent),
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
                        : tokens.color.accent,
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
