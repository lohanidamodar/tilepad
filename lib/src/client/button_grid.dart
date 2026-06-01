import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/button.dart';
import '../utils/accessibility.dart';
import '../utils/macro_icons.dart';
import '../utils/theme.dart';
import 'client_providers.dart';

/// Widget that displays a grid of macro buttons with enhanced visual feedback
class ButtonGrid extends ConsumerWidget {
  /// The list of buttons to display
  final List<Button> buttons;

  /// Called when a button is pressed
  final Function(String buttonId)? onButtonPressed;

  /// Function to convert a hex color string to a Color object.
  ///
  /// Defensive against malformed values received over the network: falls back
  /// to the default button color instead of throwing and crashing the grid.
  Color _hexToColor(String hexString) {
    var hexColor = hexString.replaceAll('#', '').trim();
    // Allow shorthand and ARGB strings, otherwise normalise to RRGGBB.
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    final value = int.tryParse(hexColor, radix: 16);
    if (value == null || hexColor.length != 8) {
      return const Color(0xFF4285F4); // Default Google blue
    }
    return Color(value);
  }

  /// Resolves a stored icon identifier to its Phosphor [IconData].
  IconData _getIconData(String iconName) => MacroIcons.resolve(iconName);

  /// Creates a new button grid
  const ButtonGrid({super.key, required this.buttons, this.onButtonPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    if (buttons.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spaceXXLarge),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.grid_view_rounded,
                size: 64,
                color: colorScheme.primary.withValues(alpha: 0.6),
              ),
              const SizedBox(height: AppTheme.spaceLarge),
              Text(
                'No buttons available',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTheme.spaceSmall),
              Text(
                'Buttons will appear here when connected to a server',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Adapt the column count to the available width so the grid feels right
    // on small phones, large phones in landscape, and tablets alike.
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnCountForWidth(constraints.maxWidth);
        return GridView.builder(
          padding: const EdgeInsets.all(AppTheme.spaceLarge),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppTheme.spaceMedium,
            mainAxisSpacing: AppTheme.spaceMedium,
            childAspectRatio: 1.0,
          ),
          itemCount: buttons.length,
          itemBuilder: (context, index) {
            final button = buttons[index];
            return _buildButton(context, button, ref);
          },
        );
      },
    );
  }

  /// Chooses a comfortable column count for the available [width] so the macro
  /// grid adapts across phones (portrait/landscape) and tablets.
  static int _columnCountForWidth(double width) {
    if (width < 320) return 2;
    if (width < 480) return 3; // standard phone portrait
    if (width < 600) return 4; // large / landscape phone
    if (width < 840) return 5; // small tablet / wide landscape
    if (width < 1080) return 6;
    return 7;
  }

  /// Handles connection loss and shows a reconnection dialog
  void _handleConnectionLoss(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final connectionState = ref.read(connectionStateProvider);

    // Provide haptic feedback
    AccessibilityUtils.provideFeedback(FeedbackType.medium);

    // Announce connection loss to screen readers
    AccessibilityUtils.announce(context, 'Connection to server lost');

    // Show dialog to inform the user
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            icon: Icon(
              Icons.wifi_off_rounded,
              color: colorScheme.error,
              size: 32,
            ),
            title: const Text('Connection Lost'),
            content: const Text(
              'The connection to the server has been lost. Would you like to reconnect?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Attempt to reconnect if we have connection info
                  if (connectionState.connection != null) {
                    AccessibilityUtils.announce(
                      context,
                      'Attempting to reconnect',
                    );
                    ref
                        .read(connectionStateProvider.notifier)
                        .connect(connectionState.connection!);
                  }
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reconnect'),
              ),
            ],
          ),
    );
  }

  /// Builds a single button widget with enhanced animations and accessibility
  Widget _buildButton(BuildContext context, Button button, WidgetRef ref) {
    final buttonColor = _hexToColor(button.color);
    final isConnected =
        ref.read(connectionStateProvider).status == ConnectionStatus.connected;

    return AccessibleButton(
      label: button.name,
      hint: AccessibilityUtils.getButtonStateLabel(isConnected, false),
      enabled: isConnected,
      onPressed: () {
        // Check if connection is active before sending command
        if (isConnected) {
          // Note: AccessibleButton already provides light haptic feedback on
          // tap-down, so we avoid a duplicate buzz here.

          // Announce button press to screen readers
          AccessibilityUtils.announce(context, 'Activated ${button.name}');

          if (onButtonPressed != null) {
            onButtonPressed!(button.id);
          }
        } else {
          // Connection is lost, show dialog to reconnect
          _handleConnectionLoss(context, ref);
        }
      },
      child: AnimatedButton(
        color: buttonColor,
        icon: _getIconData(button.iconName),
        label: button.name,
        isEnabled: isConnected,
        onPressed: () {
          // This will be handled by AccessibleButton
        },
      ),
    );
  }
}

/// Visual representation of a macro button.
///
/// Press scaling and haptics are handled by the surrounding [AccessibleButton];
/// this widget is purely visual. Sizing scales with the available tile size so
/// the same button looks right whether the grid shows 2 columns or 7.
class AnimatedButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isEnabled;

  const AnimatedButton({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        isEnabled ? color : color.withValues(alpha: 0.45);

    // Pick a legible foreground (light or dark) for the button's colour so
    // labels stay readable on both bright and dark custom button colours.
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : const Color(0xFF1A1A1A);
    final fg = isEnabled ? onColor : onColor.withValues(alpha: 0.6);

    return LayoutBuilder(
      builder: (context, constraints) {
        final tile = constraints.biggest.shortestSide;
        final iconSize = (tile * 0.30).clamp(20.0, 40.0);
        final fontSize = (tile * 0.115).clamp(11.0, 15.0);

        return Material(
          color: effectiveColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          elevation: isEnabled ? 3 : 0,
          shadowColor: color.withValues(alpha: 0.4),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  effectiveColor,
                  Color.alphaBlend(
                    Colors.black.withValues(alpha: 0.14),
                    effectiveColor,
                  ),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceSmall),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(tile * 0.07),
                    decoration: BoxDecoration(
                      color: onColor.withValues(alpha: isEnabled ? 0.18 : 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: iconSize, color: fg),
                  ),
                  SizedBox(height: tile * 0.06),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
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
}
