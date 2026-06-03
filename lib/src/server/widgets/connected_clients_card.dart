import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../design/design.dart';
import '../../models/client_info.dart';

/// A flat, minimal list of connected clients with per-client management
/// (disconnect / block) and a list of blocked addresses.
class ConnectedClientsCard extends StatelessWidget {
  final List<ClientInfo> connectedClients;

  /// Currently blocked IP addresses.
  final Set<String> blockedIps;

  /// Kicks a client off the server.
  final void Function(ClientInfo client)? onDisconnect;

  /// Blocks the client's IP (also disconnects it).
  final void Function(ClientInfo client)? onBlock;

  /// Removes an IP from the blocklist.
  final void Function(String ip)? onUnblock;

  const ConnectedClientsCard({
    super.key,
    required this.connectedClients,
    this.blockedIps = const {},
    this.onDisconnect,
    this.onBlock,
    this.onUnblock,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(t.space.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Connected', style: textTheme.titleMedium),
                const Spacer(),
                Text(
                  '${connectedClients.length}',
                  style: textTheme.labelMedium?.copyWith(color: t.color.textMuted),
                ),
              ],
            ),
            if (connectedClients.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: t.space.xl),
                child: Center(
                  child: Text(
                    'No clients connected',
                    style: textTheme.bodyMedium?.copyWith(color: t.color.textMuted),
                  ),
                ),
              )
            else
              ...List.generate(connectedClients.length, (index) {
                return Column(
                  children: [
                    SizedBox(height: t.space.lg),
                    if (index > 0) ...[
                      Divider(height: t.border.hairline, color: t.color.border),
                      SizedBox(height: t.space.lg),
                    ],
                    _client(context, t, connectedClients[index]),
                  ],
                );
              }),
            if (blockedIps.isNotEmpty) _blockedSection(context, t),
          ],
        ),
      ),
    );
  }

  Widget _client(BuildContext context, AppTokens t, ClientInfo client) {
    final textTheme = Theme.of(context).textTheme;
    final duration = DateTime.now().difference(client.connectedAt);
    final since = DateFormat('h:mm a').format(client.connectedAt);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.smartphone_outlined, size: t.icon.lg, color: t.color.textMuted),
        SizedBox(width: t.space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      client.deviceName ?? 'Unknown device',
                      style: textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: t.space.sm),
                  Container(
                    width: t.space.xs + t.space.xxs,
                    height: t.space.xs + t.space.xxs,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.color.success,
                    ),
                  ),
                ],
              ),
              SizedBox(height: t.space.xxs),
              Text(
                '${client.ipAddress} · $since · ${_formatDuration(duration)}',
                style: AppTypography.mono(
                  fontSize: t.typeScale.label,
                  color: t.color.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (onDisconnect != null || onBlock != null)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: t.icon.md, color: t.color.textMuted),
            tooltip: 'Manage client',
            onSelected: (value) {
              switch (value) {
                case 'disconnect':
                  onDisconnect?.call(client);
                  break;
                case 'block':
                  _confirmBlock(context, client);
                  break;
              }
            },
            itemBuilder: (context) => [
              if (onDisconnect != null)
                const PopupMenuItem(
                  value: 'disconnect',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.link_off),
                    title: Text('Disconnect'),
                  ),
                ),
              if (onBlock != null)
                PopupMenuItem(
                  value: 'block',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.block, color: t.color.danger),
                    title: Text(
                      'Block IP',
                      style: TextStyle(color: t.color.danger),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _confirmBlock(BuildContext context, ClientInfo client) async {
    final t = context.tokens;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block IP address'),
        content: Text(
          'Block ${client.ipAddress}? The client will be disconnected and '
          'prevented from reconnecting until you unblock it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: t.color.danger,
              foregroundColor: t.color.onAccent,
            ),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed == true) onBlock?.call(client);
  }

  Widget _blockedSection(BuildContext context, AppTokens t) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: t.space.xl),
        Divider(height: t.border.hairline, color: t.color.border),
        SizedBox(height: t.space.lg),
        Text(
          'BLOCKED',
          style: textTheme.labelSmall?.copyWith(
            color: t.color.textMuted,
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(height: t.space.sm),
        ...blockedIps.map(
          (ip) => Padding(
            padding: EdgeInsets.symmetric(vertical: t.space.xs),
            child: Row(
              children: [
                Icon(Icons.block, size: t.icon.md, color: t.color.danger),
                SizedBox(width: t.space.md),
                Expanded(
                  child: Text(
                    ip,
                    style: AppTypography.mono(
                      fontSize: t.typeScale.label,
                      color: t.color.textSecondary,
                    ),
                  ),
                ),
                if (onUnblock != null)
                  TextButton(
                    onPressed: () => onUnblock!.call(ip),
                    child: const Text('Unblock'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    }
    return '${duration.inSeconds}s';
  }
}
