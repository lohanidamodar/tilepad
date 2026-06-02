import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/design.dart';

/// A flat, minimal server status block: a status line, the connection details
/// as quiet key/value rows, and restrained start/stop controls.
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
    final statusColor = isRunning ? t.color.success : t.color.textMuted;
    final url = 'http://$serverIp:$serverPort';

    return Card(
      child: Padding(
        padding: EdgeInsets.all(t.space.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Dot(color: statusColor, glow: isRunning),
                SizedBox(width: t.space.sm),
                Text('Server', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text(
                  isRunning ? 'Running' : 'Stopped',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: statusColor,
                      ),
                ),
              ],
            ),
            SizedBox(height: t.space.lg),
            Divider(height: t.border.hairline, color: t.color.border),
            SizedBox(height: t.space.lg),
            _kv(context, t, 'Address', _mono(t, serverIp)),
            SizedBox(height: t.space.md),
            _kv(
              context,
              t,
              'Port',
              Row(
                children: [
                  _mono(t, serverPort.toString()),
                  const Spacer(),
                  _MiniIcon(
                    icon: Icons.edit_outlined,
                    tooltip: 'Change port',
                    onPressed: onChangePort,
                  ),
                ],
              ),
            ),
            SizedBox(height: t.space.md),
            _kv(
              context,
              t,
              'URL',
              Row(
                children: [
                  Expanded(child: _mono(t, url)),
                  _MiniIcon(
                    icon: Icons.copy_outlined,
                    tooltip: 'Copy URL',
                    onPressed: () => Clipboard.setData(ClipboardData(text: url)),
                  ),
                ],
              ),
            ),
            SizedBox(height: t.space.lg),
            Divider(height: t.border.hairline, color: t.color.border),
            SizedBox(height: t.space.lg),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onToggleServer,
                    style: isRunning
                        ? FilledButton.styleFrom(
                            backgroundColor: t.color.dangerSubtle,
                            foregroundColor: t.color.danger,
                          )
                        : null,
                    child: Text(isRunning ? 'Stop' : 'Start'),
                  ),
                ),
                SizedBox(width: t.space.sm),
                OutlinedButton(
                  onPressed: isRunning ? onRestartServer : null,
                  child: const Text('Restart'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// A label/value row: muted fixed-width label on the left, value on the right.
  Widget _kv(BuildContext context, AppTokens t, String label, Widget value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: t.space.huge + t.space.xl,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: t.color.textMuted,
                ),
          ),
        ),
        Expanded(child: value),
      ],
    );
  }

  Widget _mono(AppTokens t, String text) => Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.mono(
          fontSize: t.typeScale.bodySm,
          color: t.color.textPrimary,
        ),
      );
}

/// A small status dot, optionally with a soft glow when active.
class _Dot extends StatelessWidget {
  final Color color;
  final bool glow;
  const _Dot({required this.color, required this.glow});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: t.space.sm,
      height: t.space.sm,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: glow
            ? [BoxShadow(color: color, blurRadius: t.space.sm)]
            : const [],
      ),
    );
  }
}

/// A compact, quiet icon button for inline row affordances.
class _MiniIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  const _MiniIcon({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: t.icon.sm),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      color: t.color.textMuted,
      padding: EdgeInsets.all(t.space.xs),
      constraints: const BoxConstraints(),
    );
  }
}
