import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/button.dart';
import '../models/window_info.dart';
import '../design/design.dart';
import '../utils/accessibility.dart';
import '../utils/macro_icons.dart';
import '../widgets/key_combo_picker.dart';
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
    if (buttons.isEmpty) {
      return Center(
        child: Container(
          padding: EdgeInsets.all(context.tokens.space.xxxl),
          decoration: BoxDecoration(
            color: context.tokens.color.surfaceSubtle,
            borderRadius: context.tokens.radius.brLg,
            border: Border.all(color: context.tokens.color.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.grid_view_rounded,
                size: context.tokens.icon.xl,
                color: context.tokens.color.textMuted,
              ),
              SizedBox(height: context.tokens.space.lg),
              Text(
                'No buttons available',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: context.tokens.color.textSecondary,
                ),
              ),
              SizedBox(height: context.tokens.space.sm),
              Text(
                'Buttons will appear here when connected to a server',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.tokens.color.textMuted,
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
          padding: EdgeInsets.all(context.tokens.space.lg),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: context.tokens.space.md,
            mainAxisSpacing: context.tokens.space.md,
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
              color: context.tokens.color.danger,
              size: context.tokens.icon.xl,
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

    // Resolve a live-tile binding: a plugin state can drive the title or icon.
    var label = button.name;
    var icon = _getIconData(button.iconName);
    final binding = button.stateBinding;
    if (binding != null) {
      // Watch only this binding's key so unrelated state changes don't rebuild
      // every live tile.
      final key =
          PluginStatesNotifier.keyFor(binding.pluginId, binding.stateId);
      final value =
          ref.watch(pluginStatesProvider.select((states) => states[key]));
      if (value != null) {
        if (binding.mode == StateBindingMode.title &&
            value.displayText.isNotEmpty) {
          label = value.displayText;
        } else if (binding.mode == StateBindingMode.icon &&
            value.image != null &&
            value.image!.isNotEmpty) {
          icon = _getIconData(value.image!);
        }
      }
    }

    return AccessibleButton(
      label: label,
      hint: AccessibilityUtils.getButtonStateLabel(isConnected, false),
      enabled: isConnected,
      onPressed: () {
        // Check if connection is active before sending command
        if (!isConnected) {
          // Connection is lost, show dialog to reconnect
          _handleConnectionLoss(context, ref);
          return;
        }

        // Note: AccessibleButton already provides light haptic feedback on
        // tap-down, so we avoid a duplicate buzz here.
        AccessibilityUtils.announce(context, 'Activated ${button.name}');

        if (button.isPrompt) {
          // Dynamic button: ask the user what to send, then send it.
          _handleDynamicPress(context, ref, button);
        } else if (onButtonPressed != null) {
          onButtonPressed!(button.id);
        }
      },
      child: AnimatedButton(
        color: buttonColor,
        icon: icon,
        label: label,
        isEnabled: isConnected,
        onPressed: () {
          // This will be handled by AccessibleButton
        },
      ),
    );
  }

  /// Last value sent from each dynamic button, used to prefill the prompt.
  static final Map<String, String> _lastText = {};
  static final Map<String, ({String key, Set<String> modifiers})> _lastCombo =
      {};

  /// Handles pressing a dynamic button by asking the user what to send.
  Future<void> _handleDynamicPress(
    BuildContext context,
    WidgetRef ref,
    Button button,
  ) async {
    final notifier = ref.read(connectionStateProvider.notifier);

    if (button.promptActionType == ActionType.promptText) {
      final text = await _showTextPrompt(context, button);
      if (text != null && text.isNotEmpty) {
        _lastText[button.id] = text;
        notifier.pressButton(button.id, text: text);
      }
    } else if (button.promptActionType == ActionType.promptKeystroke) {
      final combo = await _showKeyComboPrompt(context, button);
      if (combo != null) {
        _lastCombo[button.id] = combo;
        notifier.pressButton(
          button.id,
          key: combo.key,
          modifiers: combo.modifiers.toList(),
        );
      }
    } else if (button.promptActionType == ActionType.selectWindow) {
      final windowId = await _showWindowPicker(context, ref, button);
      if (windowId != null) {
        notifier.pressButton(button.id, windowId: windowId);
      }
    }
  }

  /// Fetches the server's open windows and lets the user pick one to focus.
  Future<String?> _showWindowPicker(
    BuildContext context,
    WidgetRef ref,
    Button button,
  ) {
    final future = ref.read(connectionStateProvider.notifier).fetchWindows();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(button.name),
          content: SizedBox(
            width: 380,
            height: 420,
            child: FutureBuilder<List<WindowInfo>>(
              future: future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final windows = snapshot.data ?? const <WindowInfo>[];
                if (windows.isEmpty) {
                  return const Center(child: Text('No open windows found'));
                }
                return ListView.separated(
                  itemCount: windows.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final window = windows[index];
                    return ListTile(
                      leading: const Icon(Icons.web_asset),
                      title: Text(
                        window.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.of(context).pop(window.id),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  /// Prompts for free text to send.
  Future<String?> _showTextPrompt(BuildContext context, Button button) {
    final controller = TextEditingController(text: _lastText[button.id] ?? '');
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(button.name),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Text to send',
              hintText: 'Type the text to send…',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(controller.text),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  /// Prompts for a key combination to send.
  Future<({String key, Set<String> modifiers})?> _showKeyComboPrompt(
    BuildContext context,
    Button button,
  ) {
    final last = _lastCombo[button.id];
    var key = last?.key ?? 'a';
    var modifiers = {...?last?.modifiers};
    return showDialog<({String key, Set<String> modifiers})>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(button.name),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: KeyComboPicker(
                initialKey: key,
                initialModifiers: modifiers,
                onChanged: (k, m) {
                  key = k;
                  modifiers = m;
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed:
                  () => Navigator.of(
                    context,
                  ).pop((key: key, modifiers: modifiers)),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Send'),
            ),
          ],
        );
      },
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
        final iconSize = (tile * 0.42).clamp(28.0, 56.0);
        final fontSize = (tile * 0.115).clamp(10.0, 14.0);

        return Material(
          color: effectiveColor,
          borderRadius: BorderRadius.circular(context.tokens.radius.lg),
          elevation: isEnabled ? 3 : 0,
          shadowColor: color.withValues(alpha: 0.4),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.tokens.radius.lg),
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
              padding: EdgeInsets.all(context.tokens.space.sm),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: iconSize, color: fg),
                  SizedBox(height: tile * 0.05),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w700,
                        height: 1.05,
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
