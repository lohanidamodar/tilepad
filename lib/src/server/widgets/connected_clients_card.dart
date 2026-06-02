import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../design/design.dart';
import '../../models/client_info.dart';

/// A card widget that displays connected clients
class ConnectedClientsCard extends StatelessWidget {
  final List<ClientInfo> connectedClients;

  const ConnectedClientsCard({super.key, required this.connectedClients});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      margin: EdgeInsets.symmetric(vertical: t.space.sm),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, t),
            Padding(
              padding: EdgeInsets.all(t.space.xl),
              child: _buildClientsList(context, t),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppTokens t) {
    final hasClients = connectedClients.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: t.space.xl,
        vertical: t.space.lg,
      ),
      decoration: BoxDecoration(color: t.color.accentSubtle),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(t.space.sm),
            decoration: BoxDecoration(
              color: t.color.accent.withValues(alpha: t.opacity.subtle),
              borderRadius: t.radius.brSm,
            ),
            child: Icon(
              Icons.devices_rounded,
              color: t.color.accent,
              size: t.icon.lg,
            ),
          ),
          SizedBox(width: t.space.md),
          Text(
            'Connected Clients',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: t.color.textPrimary,
                ),
          ),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: t.space.md,
              vertical: t.space.xs,
            ),
            decoration: BoxDecoration(
              color: hasClients ? t.color.successSubtle : t.color.surfaceSubtle,
              borderRadius: t.radius.brLg,
              border: Border.all(
                color: hasClients ? t.color.success : t.color.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: t.space.sm,
                  height: t.space.sm,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasClients ? t.color.success : t.color.textMuted,
                  ),
                ),
                SizedBox(width: t.space.xs),
                Text(
                  '${connectedClients.length}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: hasClients
                            ? t.color.success
                            : t.color.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientsList(BuildContext context, AppTokens t) {
    if (connectedClients.isEmpty) {
      return _buildEmptyState(context, t);
    }

    final dateFormat = DateFormat('h:mm:ss a');

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: connectedClients.length,
      separatorBuilder: (context, index) => SizedBox(height: t.space.md),
      itemBuilder: (context, index) {
        final client = connectedClients[index];
        final connectionDuration = DateTime.now().difference(
          client.connectedAt,
        );

        return Container(
          decoration: BoxDecoration(
            color: t.color.surfaceSubtle,
            borderRadius: t.radius.brMd,
            border: Border.all(color: t.color.border),
          ),
          child: Padding(
            padding: EdgeInsets.all(t.space.lg),
            child: Row(
              children: [
                _buildDeviceIcon(t),
                SizedBox(width: t.space.lg),
                Expanded(
                  child: _buildClientInfo(
                    context,
                    t,
                    client,
                    dateFormat,
                    connectionDuration,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, AppTokens t) {
    return Container(
      padding: EdgeInsets.all(t.space.xxl),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.color.surfaceSubtle,
        borderRadius: t.radius.brMd,
        border: Border.all(
          color: t.color.border,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(t.space.lg),
            decoration: BoxDecoration(
              color: t.color.surfaceRaised,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.smartphone_rounded,
              size: t.space.xxxl,
              color: t.color.textMuted,
            ),
          ),
          SizedBox(height: t.space.lg),
          Text(
            'No clients connected',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: t.color.textSecondary,
                ),
          ),
          SizedBox(height: t.space.sm),
          Text(
            'Clients will appear here when they connect to the server',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: t.color.textMuted,
                  fontStyle: FontStyle.italic,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceIcon(AppTokens t) {
    return Container(
      padding: EdgeInsets.all(t.space.md),
      decoration: BoxDecoration(
        color: t.color.accentSubtle,
        borderRadius: t.radius.brMd,
      ),
      child: Icon(
        Icons.smartphone_rounded,
        size: t.icon.xl,
        color: t.color.accent,
      ),
    );
  }

  Widget _buildClientInfo(
    BuildContext context,
    AppTokens t,
    ClientInfo client,
    DateFormat dateFormat,
    Duration connectionDuration,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                client.deviceName ?? 'Unknown Device',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: t.color.textPrimary,
                    ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: t.space.sm,
                vertical: t.space.xs,
              ),
              decoration: BoxDecoration(
                color: t.color.successSubtle,
                borderRadius: t.radius.brMd,
                border: Border.all(color: t.color.success),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: t.space.xs + t.space.xxs,
                    height: t.space.xs + t.space.xxs,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.color.success,
                    ),
                  ),
                  SizedBox(width: t.space.xs),
                  Text(
                    'Online',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: t.color.success,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: t.space.sm),
        Wrap(
          spacing: t.space.lg,
          runSpacing: t.space.xs,
          children: [
            _buildInfoChip(context, t, Icons.location_on, client.ipAddress,
                mono: true),
            _buildInfoChip(
              context,
              t,
              Icons.access_time,
              dateFormat.format(client.connectedAt),
              mono: true,
            ),
            _buildInfoChip(
              context,
              t,
              Icons.timer,
              _formatDuration(connectionDuration),
              mono: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoChip(
    BuildContext context,
    AppTokens t,
    IconData icon,
    String text, {
    bool mono = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: t.icon.xs, color: t.color.accent),
        SizedBox(width: t.space.xs),
        Text(
          text,
          style: mono
              ? AppTypography.mono(
                  fontSize: t.typeScale.label,
                  color: t.color.textSecondary,
                )
              : Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: t.color.textSecondary,
                  ),
        ),
      ],
    );
  }

  /// Format duration in a human-readable way
  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}
