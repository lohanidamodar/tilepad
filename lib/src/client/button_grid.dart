import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../models/button.dart';
import '../models/window_info.dart';
import '../design/design.dart';
import '../utils/accessibility.dart';
import '../utils/macro_icons.dart';
import '../widgets/key_combo_picker.dart';
import 'client_providers.dart';

/// Computes the page index a navigation [target] should switch to, given the
/// [current] index and total page [count]. `next`/`prev` wrap around; an
/// `index:N` or bare integer target jumps to a clamped absolute page; a
/// `page:<pageId>` target jumps to that page's position in [pageIds] (staying
/// put if the page no longer exists).
int resolveNavigationIndex(
  String target,
  int current,
  int count, {
  List<String> pageIds = const [],
}) {
  if (count <= 0) return current;
  final last = count - 1;
  if (target.startsWith('page:')) {
    final index = pageIds.indexOf(target.substring('page:'.length));
    return index == -1 ? current : index.clamp(0, last);
  }
  switch (target) {
    case 'next':
      return current >= last ? 0 : current + 1;
    case 'prev':
    case 'previous':
      return current <= 0 ? last : current - 1;
    case 'first':
      return 0;
    case 'last':
      return last;
    default:
      final parsed = int.tryParse(target.replaceFirst('index:', ''));
      if (parsed == null) return current;
      return parsed.clamp(0, last);
  }
}

/// Widget that displays a spanning grid of macro button tiles with enhanced
/// visual feedback.
class ButtonGrid extends ConsumerWidget {
  /// The tiles (button placements) to display.
  final List<Tile> tiles;

  /// Number of grid columns the tiles' spans are laid out against.
  final int columns;

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
  const ButtonGrid({
    super.key,
    required this.tiles,
    required this.columns,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tiles.isEmpty) {
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

    // The page defines the column count; the staggered grid sizes each cell to
    // fill the available width, so per-tile spans scale across phone sizes.
    // At least one column so a malformed page never divides by zero.
    final crossAxisCount = columns > 0 ? columns : 1;

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.tokens.space.lg),
      child: StaggeredGrid.count(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: context.tokens.space.md,
        crossAxisSpacing: context.tokens.space.md,
        children: [
          for (final tile in tiles)
            StaggeredGridTile.count(
              crossAxisCellCount: tile.colSpan.clamp(1, crossAxisCount),
              mainAxisCellCount: tile.rowSpan < 1 ? 1 : tile.rowSpan,
              child: _buildButton(context, tile.button, ref),
            ),
        ],
      ),
    );
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
    // Toggle buttons render the face that's currently active on the server.
    final buttonColor = _hexToColor(button.effectiveColor);
    final isConnected =
        ref.read(connectionStateProvider).status == ConnectionStatus.connected;

    // Resolve a live-tile binding: a bound state can drive the live value
    // (shown under the name) or swap the icon.
    final label = button.effectiveName;
    var icon = _getIconData(button.effectiveIconName);
    String? liveValue;
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
          liveValue = value.displayText;
        } else if (binding.mode == StateBindingMode.icon &&
            value.image != null &&
            value.image!.isNotEmpty) {
          icon = _getIconData(value.image!);
        }
      }
    }

    return AccessibleButton(
      label: liveValue == null ? label : '$label $liveValue',
      hint: AccessibilityUtils.getButtonStateLabel(isConnected, false),
      enabled: isConnected,
      onPressed: () {
        // Display-only tiles (no actions, not a prompt — e.g. system-info
        // tiles) do nothing on tap instead of pressing and erroring.
        if (button.actions.isEmpty && !button.isPrompt) return;

        // Page-navigation buttons act entirely on the client — no server round
        // trip, and they work even while reconnecting.
        if (button.navigationTarget != null) {
          AccessibilityUtils.announce(context, 'Activated ${button.effectiveName}');
          _navigatePage(ref, button.navigationTarget!);
          return;
        }

        // Check if connection is active before sending command
        if (!isConnected) {
          // Connection is lost, show dialog to reconnect
          _handleConnectionLoss(context, ref);
          return;
        }

        // Note: AccessibleButton already provides light haptic feedback on
        // tap-down, so we avoid a duplicate buzz here.
        AccessibilityUtils.announce(context, 'Activated ${button.effectiveName}');

        if (button.isPrompt) {
          // Dynamic button: ask the user what to send, then send it.
          _handleDynamicPress(context, ref, button);
        } else if (onButtonPressed != null) {
          onButtonPressed!(button.id);
        }
      },
      // Buttons with a hold action set get a distinct long-press gesture;
      // others keep plain taps so holding doesn't change their behaviour.
      onLongPress: button.longPressActions.isEmpty
          ? null
          : () {
              if (!isConnected) {
                _handleConnectionLoss(context, ref);
                return;
              }
              AccessibilityUtils.announce(context, 'Held ${button.effectiveName}');
              ref
                  .read(connectionStateProvider.notifier)
                  .pressButton(button.id, longPress: true);
            },
      child: AnimatedButton(
        color: buttonColor,
        icon: icon,
        label: label,
        liveValue: liveValue,
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

  /// Switches the visible page for a [ActionType.navigatePage] button.
  /// `page:<pageId>` jumps to a specific page; other targets are relative.
  void _navigatePage(WidgetRef ref, String target) {
    final pages = ref.read(pagesProvider);
    if (pages.isEmpty) return;
    final current = ref.read(selectedPageIndexProvider);
    final next = resolveNavigationIndex(
      target,
      current,
      pages.length,
      pageIds: [for (final p in pages) p.id],
    );
    if (next != current) {
      ref.read(selectedPageIndexProvider.notifier).set(next);
    }
  }

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
  /// The list is fetched fresh on every open, and the refresh button refetches
  /// without closing the dialog (windows come and go while it's up).
  Future<String?> _showWindowPicker(
    BuildContext context,
    WidgetRef ref,
    Button button,
  ) {
    final notifier = ref.read(connectionStateProvider.notifier);
    var future = notifier.fetchWindows();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      button.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Refresh window list',
                    onPressed: () => setDialogState(() {
                      future = notifier.fetchWindows();
                    }),
                  ),
                ],
              ),
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
      },
    );
  }

  /// Prompts for free text to send. The field prefills with the last sent
  /// text; the clear icon empties it and forgets the prefill.
  Future<String?> _showTextPrompt(BuildContext context, Button button) {
    final controller = TextEditingController(text: _lastText[button.id] ?? '');
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(button.name),
          content: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => TextField(
              controller: controller,
              autofocus: true,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Text to send',
                hintText: 'Type the text to send…',
                border: const OutlineInputBorder(),
                suffixIcon: value.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        tooltip: 'Clear',
                        onPressed: () {
                          controller.clear();
                          _lastText.remove(button.id);
                        },
                      ),
              ),
              onSubmitted: (v) => Navigator.of(context).pop(v),
            ),
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

  /// Prompts for a key combination to send. The picker prefills with the last
  /// sent combo; Clear resets it to the default and forgets the prefill.
  Future<({String key, Set<String> modifiers})?> _showKeyComboPrompt(
    BuildContext context,
    Button button,
  ) {
    final last = _lastCombo[button.id];
    var key = last?.key ?? 'a';
    var modifiers = {...?last?.modifiers};
    // Bumped to give the picker a fresh Key, so it rebuilds from the reset
    // initial values (it keeps the combo in its own state).
    var generation = 0;
    return showDialog<({String key, Set<String> modifiers})>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(button.name),
              content: SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: KeyComboPicker(
                    key: ValueKey(generation),
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
                  onPressed: () => setDialogState(() {
                    key = 'a';
                    modifiers = {};
                    _lastCombo.remove(button.id);
                    generation++;
                  }),
                  child: const Text('Clear'),
                ),
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

  /// Live value from a bound state (e.g. "42%"); shown prominently under the
  /// name when present.
  final String? liveValue;
  final VoidCallback onPressed;
  final bool isEnabled;

  const AnimatedButton({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
    this.liveValue,
    required this.onPressed,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    // Luminance-adaptive foreground so labels stay readable on ANY user colour
    // (white on dark colours, near-black on light ones). The whole tile fades
    // together when disabled, so contrast is preserved in every state.
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : const Color(0xFF18181B);

    return Opacity(
      opacity: isEnabled ? 1.0 : t.opacity.muted,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tile = constraints.biggest.shortestSide;
          final hasLive = liveValue != null && liveValue!.isNotEmpty;
          // A multi-metric readout (e.g. the System Monitor) renders as aligned
          // monospace lines rather than one big value.
          final isMulti = hasLive && liveValue!.contains('\n');
          final iconSize =
              (tile * (isMulti ? 0.18 : (hasLive ? 0.28 : 0.42)))
                  .clamp(16.0, 56.0);
          final fontSize = (tile * 0.115).clamp(10.0, 14.0);

          return Material(
            color: color,
            borderRadius: BorderRadius.circular(t.radius.lg),
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(t.space.sm),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // The multi-metric tile drops the big icon to make room for
                  // all the metric lines.
                  if (!isMulti) ...[
                    Icon(icon, size: iconSize, color: onColor),
                    SizedBox(height: tile * 0.04),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: hasLive ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasLive ? onColor.withValues(alpha: 0.8) : onColor,
                        fontSize: hasLive ? fontSize * 0.85 : fontSize,
                        fontWeight: hasLive ? FontWeight.w600 : FontWeight.w700,
                        height: 1.05,
                      ),
                    ),
                  ),
                  if (hasLive) ...[
                    SizedBox(height: tile * 0.03),
                    Flexible(
                      child: Text(
                        liveValue!,
                        textAlign: isMulti ? TextAlign.left : TextAlign.center,
                        maxLines: isMulti ? 6 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: onColor,
                          fontFamily: isMulti ? 'monospace' : null,
                          fontSize: isMulti
                              ? (tile * 0.105).clamp(10.0, 15.0)
                              : (tile * 0.16).clamp(13.0, 22.0),
                          fontWeight:
                              isMulti ? FontWeight.w600 : FontWeight.w700,
                          height: isMulti ? 1.3 : 1.0,
                          letterSpacing: isMulti ? -0.3 : 0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
