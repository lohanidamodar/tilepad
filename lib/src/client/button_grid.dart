import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/button.dart';
import '../network/websocket_service.dart';
import 'client_providers.dart';

/// Widget that displays a grid of macro buttons
class ButtonGrid extends ConsumerWidget {
  /// The list of buttons to display
  final List<Button> buttons;

  /// Called when a button is pressed
  final Function(String buttonId)? onButtonPressed;

  /// Function to convert a hex color string to a Color object
  Color _hexToColor(String hexString) {
    final hexColor = hexString.replaceAll('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
  }

  /// Function to convert an icon name string to an IconData object
  IconData _getIconData(String iconName) {
    try {
      // Try to parse the icon as a code point
      final codePoint = int.tryParse(iconName);
      if (codePoint != null) {
        // Use FontAwesomeSolid font family for FontAwesome icons
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
    if (buttons.isEmpty) {
      return const Center(
        child: Text('No buttons available', style: TextStyle(fontSize: 18)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
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

    // Show dialog to inform the user
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error_outline, color: colorScheme.error),
                const SizedBox(width: 12),
                const Text('Connection Lost'),
              ],
            ),
            content: const Text(
              'The connection to the server has been lost. Would you like to reconnect?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();

                  // Attempt to reconnect if we have connection info
                  if (connectionState.connection != null) {
                    ref
                        .read(connectionStateProvider.notifier)
                        .connect(connectionState.connection!);
                  }
                },
                child: const Text('Reconnect'),
              ),
            ],
          ),
    );
  }

  /// Builds a single button widget
  Widget _buildButton(BuildContext context, Button button, WidgetRef ref) {
    return Material(
      color: _hexToColor(button.color),
      borderRadius: BorderRadius.circular(12),
      elevation: 3,
      child: InkWell(
        onTap: () {
          // Check if connection is active before sending command
          if (ref.read(connectionStateProvider).status ==
              ConnectionStatus.connected) {
            if (onButtonPressed != null) {
              onButtonPressed!(button.id);
            }
          } else {
            // Connection is lost, show dialog to reconnect
            _handleConnectionLoss(context, ref);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              _getIconData(button.iconName),
              size: 32,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            Text(
              button.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
