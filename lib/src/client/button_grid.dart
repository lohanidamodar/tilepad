import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/button.dart';
import '../utils/accessibility.dart';
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

  /// Function to convert an icon name string to an IconData object
  IconData _getIconData(String iconName) {
    try {
      // Try to parse the icon as a code point
      final codePoint = int.tryParse(iconName);
      if (codePoint != null) {
        // Use FontAwesomeSolid font family for FontAwesome icons
        // Note: Non-const IconData - release builds need --no-tree-shake-icons
        return IconData(
          codePoint,
          fontFamily: 'FontAwesomeSolid',
          fontPackage: 'font_awesome_flutter',
        );
      }

      // Default to a placeholder icon
      return Icons.smart_button;
    } catch (e) {
      return Icons.smart_button;
    }
  }

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

    return GridView.builder(
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
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

/// Enhanced animated button widget with accessibility support
class AnimatedButton extends StatefulWidget {
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
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  final bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _elevationAnimation = Tween<double>(begin: 4.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        widget.isEnabled ? widget.color : widget.color.withValues(alpha: 0.5);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Material(
            color: effectiveColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            elevation: widget.isEnabled ? _elevationAnimation.value : 1.0,
            shadowColor: widget.color.withValues(alpha: 0.4),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    effectiveColor,
                    effectiveColor.withValues(alpha: 0.8),
                  ],
                ),
                boxShadow:
                    _isPressed || !widget.isEnabled
                        ? []
                        : [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spaceSmall),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: widget.isEnabled ? 0.2 : 0.1,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: FaIcon(
                      widget.icon,
                      size: 28,
                      color:
                          widget.isEnabled
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceSmall),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceXSmall,
                    ),
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            widget.isEnabled
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        shadows:
                            widget.isEnabled
                                ? [
                                  const Shadow(
                                    color: Colors.black26,
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ]
                                : [],
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
