import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/design.dart';

/// A card widget that displays the server status and controls
class ServerStatusCard extends StatelessWidget {
  final String serverIp;
  final int serverPort;
  final bool isRunning;
  final VoidCallback? onRestartServer;
  final Future<void> Function()? onToggleServer;
  final VoidCallback? onChangePort;

  const ServerStatusCard({
    super.key,
    required this.serverIp,
    required this.serverPort,
    required this.isRunning,
    this.onRestartServer,
    this.onToggleServer,
    this.onChangePort,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AnimatedContainer(
      duration: t.motion.slow,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusHeader(context, t),
            _buildStatusContent(context, t),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(BuildContext context, AppTokens t) {
    final statusColor = isRunning ? t.color.success : t.color.danger;
    final headerBg = isRunning ? t.color.successSubtle : t.color.dangerSubtle;

    return AnimatedContainer(
      duration: t.motion.slow,
      padding: EdgeInsets.symmetric(
        horizontal: t.space.xl,
        vertical: t.space.lg,
      ),
      decoration: BoxDecoration(color: headerBg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.dns_rounded,
                color: statusColor,
                size: t.icon.xl,
              ),
              SizedBox(width: t.space.md),
              Text(
                'Server Status',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: statusColor,
                    ),
              ),
            ],
          ),
          Row(
            children: [
              AnimatedContainer(
                duration: t.motion.slow,
                width: t.space.lg,
                height: t.space.lg,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                  boxShadow: isRunning
                      ? [
                          BoxShadow(
                            color: statusColor
                                .withValues(alpha: t.opacity.subtle),
                            blurRadius: t.space.sm,
                            spreadRadius: t.space.xxs,
                          ),
                        ]
                      : [],
                ),
              ),
              SizedBox(width: t.space.md),
              Text(
                isRunning ? 'Running' : 'Stopped',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: statusColor,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusContent(BuildContext context, AppTokens t) {
    return Padding(
      padding: EdgeInsets.all(t.space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildConnectionInfo(context, t),
          SizedBox(height: t.space.xl),
          _buildConnectionUrl(context, t),
          SizedBox(height: t.space.xl),
          _buildControlButtons(context, t),
        ],
      ),
    );
  }

  Widget _buildConnectionInfo(BuildContext context, AppTokens t) {
    return Container(
      padding: EdgeInsets.all(t.space.lg),
      decoration: BoxDecoration(
        borderRadius: t.radius.brMd,
        color: t.color.surfaceSubtle,
        border: Border.all(
          color: t.color.border,
          width: t.border.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connection Details',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: t.color.textSecondary,
                ),
          ),
          SizedBox(height: t.space.lg),
          _buildInfoRow(context, t, Icons.router, 'IP Address', serverIp),
          SizedBox(height: t.space.md),
          _buildInfoRow(
            context,
            t,
            Icons.settings_ethernet,
            'Port',
            serverPort.toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    AppTokens t,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: t.icon.lg, color: t.color.accent),
        SizedBox(width: t.space.md),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: t.typeScale.wMedium,
                color: t.color.textSecondary,
              ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.mono(color: t.color.textSecondary),
          ),
        ),
        if (label == 'Port')
          IconButton(
            onPressed: onChangePort,
            icon: const Icon(Icons.edit),
            iconSize: t.icon.sm,
            tooltip: 'Change Port',
          ),
      ],
    );
  }

  Widget _buildConnectionUrl(BuildContext context, AppTokens t) {
    final url = 'http://$serverIp:$serverPort';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(t.space.lg),
      decoration: BoxDecoration(
        borderRadius: t.radius.brMd,
        color: t.color.accentSubtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link, color: t.color.accent, size: t.icon.lg),
              SizedBox(width: t.space.sm),
              Text(
                'Connection URL',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: t.color.accent,
                    ),
              ),
            ],
          ),
          SizedBox(height: t.space.md),
          Container(
            padding: EdgeInsets.all(t.space.md),
            decoration: BoxDecoration(
              color: t.color.surface,
              borderRadius: t.radius.brSm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    url,
                    style: AppTypography.mono(
                      fontSize: t.typeScale.body,
                      color: t.color.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _copyToClipboard(url),
                  icon: const Icon(Icons.copy),
                  iconSize: t.icon.sm,
                  tooltip: 'Copy URL',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons(BuildContext context, AppTokens t) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: isRunning ? onRestartServer : null,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Restart Server'),
            style: FilledButton.styleFrom(
              backgroundColor: t.color.accentSubtle,
              foregroundColor: t.color.accent,
              disabledBackgroundColor:
                  t.color.surfaceSubtle.withValues(alpha: t.opacity.disabled),
              disabledForegroundColor:
                  t.color.textMuted.withValues(alpha: t.opacity.disabled),
              padding: EdgeInsets.symmetric(vertical: t.space.lg),
            ),
          ),
        ),
        SizedBox(width: t.space.lg),
        Expanded(
          child: FilledButton.icon(
            onPressed: onToggleServer,
            icon: Icon(
              isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
            ),
            label: Text(isRunning ? 'Stop Server' : 'Start Server'),
            style: FilledButton.styleFrom(
              backgroundColor:
                  isRunning ? t.color.dangerSubtle : t.color.successSubtle,
              foregroundColor:
                  isRunning ? t.color.danger : t.color.success,
              padding: EdgeInsets.symmetric(vertical: t.space.lg),
            ),
          ),
        ),
      ],
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }
}
