import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/button.dart';

/// Widget that displays a grid of macro buttons
class ButtonGrid extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
        return _buildButton(context, button);
      },
    );
  }

  /// Builds a single button widget
  Widget _buildButton(BuildContext context, Button button) {
    return Material(
      color: _hexToColor(button.color),
      borderRadius: BorderRadius.circular(12),
      elevation: 3,
      child: InkWell(
        onTap: () {
          if (onButtonPressed != null) {
            onButtonPressed!(button.id);
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
