import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../design/design.dart';
import '../../models/client_info.dart';

/// A flat, minimal list of connected clients.
class ConnectedClientsCard extends StatelessWidget {
  final List<ClientInfo> connectedClients;

  const ConnectedClientsCard({super.key, required this.connectedClients});

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
