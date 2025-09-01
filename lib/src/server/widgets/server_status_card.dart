import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: isRunning ? 4 : 2,
        shadowColor:
            isRunning
                ? colorScheme.primary.withValues(alpha: 0.2)
                : colorScheme.shadow.withValues(alpha: 0.1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusHeader(colorScheme),
            _buildStatusContent(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(ColorScheme colorScheme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isRunning
                  ? [
                    colorScheme.primaryContainer,
                    colorScheme.primaryContainer.withValues(alpha: 0.8),
                  ]
                  : [
                    colorScheme.errorContainer,
                    colorScheme.errorContainer.withValues(alpha: 0.8),
                  ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.dns_rounded,
                color:
                    isRunning
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onErrorContainer,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Server Status',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color:
                      isRunning
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onErrorContainer,
                ),
              ),
            ],
          ),
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRunning ? colorScheme.primary : colorScheme.error,
                  boxShadow:
                      isRunning
                          ? [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                          : [],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isRunning ? 'Running' : 'Stopped',
                style: TextStyle(
                  color:
                      isRunning
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onErrorContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusContent(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildConnectionInfo(colorScheme),
          const SizedBox(height: 20),
          _buildConnectionUrl(colorScheme),
          const SizedBox(height: 20),
          _buildControlButtons(colorScheme),
        ],
      ),
    );
  }

  Widget _buildConnectionInfo(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
          ],
        ),
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connection Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.router, 'IP Address', serverIp, colorScheme),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.settings_ethernet,
            'Port',
            serverPort.toString(),
            colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (label == 'Port')
          IconButton(
            onPressed: onChangePort,
            icon: const Icon(Icons.edit),
            iconSize: 16,
            tooltip: 'Change Port',
          ),
      ],
    );
  }

  Widget _buildConnectionUrl(ColorScheme colorScheme) {
    final url = 'http://$serverIp:$serverPort';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.primaryContainer.withValues(alpha: 0.7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link, color: colorScheme.onPrimaryContainer, size: 20),
              const SizedBox(width: 8),
              Text(
                'Connection URL',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    url,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _copyToClipboard(url),
                  icon: const Icon(Icons.copy),
                  iconSize: 16,
                  tooltip: 'Copy URL',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: isRunning ? onRestartServer : null,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Restart Server'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.tertiaryContainer,
              foregroundColor: colorScheme.onTertiaryContainer,
              disabledBackgroundColor: colorScheme.surface.withValues(
                alpha: 0.3,
              ),
              disabledForegroundColor: colorScheme.onSurfaceVariant.withValues(
                alpha: 0.5,
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FilledButton.icon(
            onPressed: onToggleServer,
            icon: Icon(
              isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
            ),
            label: Text(isRunning ? 'Stop Server' : 'Start Server'),
            style: FilledButton.styleFrom(
              backgroundColor:
                  isRunning
                      ? colorScheme.errorContainer
                      : colorScheme.primaryContainer,
              foregroundColor:
                  isRunning
                      ? colorScheme.onErrorContainer
                      : colorScheme.onPrimaryContainer,
              padding: const EdgeInsets.symmetric(vertical: 16),
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
