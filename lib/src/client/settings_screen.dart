import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/design.dart';
import '../utils/accessibility.dart';
import 'client_providers.dart';

/// Provider for accessibility settings
final accessibilitySettingsProvider =
    NotifierProvider<AccessibilitySettings, AccessibilityState>(
      AccessibilitySettings.new,
    );

/// Enhanced settings screen with accessibility options
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final accessibilityState = ref.watch(accessibilitySettingsProvider);
    final keepAwake = ref.watch(keepAwakeProvider);
    final fullscreen = ref.watch(fullscreenProvider);
    final orientation = ref.watch(deckOrientationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.settings_rounded, color: t.color.accent),
            SizedBox(width: t.space.md),
            const Text('Settings'),
          ],
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: EdgeInsets.all(t.space.lg),
        children: [
          // Appearance Section (shared personalization panel)
          _buildSection(
            context: context,
            title: 'Appearance',
            icon: Icons.palette_rounded,
            children: const [
              PersonalizationPanel(),
            ],
          ),

          SizedBox(height: t.space.xxl),

          // Display Settings Section
          _buildSection(
            context: context,
            title: 'Display',
            icon: Icons.display_settings_rounded,
            children: [
              _buildToggleSetting(
                context: context,
                title: 'Keep Screen Awake',
                subtitle:
                    'Prevent the screen from turning off while using the app',
                icon: Icons.lightbulb_outline_rounded,
                value: keepAwake,
                onChanged: (value) {
                  ref.read(keepAwakeProvider.notifier).setKeepAwake(value);
                },
              ),
              SizedBox(height: t.space.lg),
              _buildToggleSetting(
                context: context,
                title: 'Fullscreen Mode',
                subtitle:
                    'Hide the status and navigation bars so the deck uses the '
                    'whole screen',
                icon: Icons.fullscreen_rounded,
                value: fullscreen,
                onChanged: (value) {
                  ref.read(fullscreenProvider.notifier).setFullscreen(value);
                },
              ),
              SizedBox(height: t.space.lg),
              _buildOrientationSetting(context, ref, orientation),
              SizedBox(height: t.space.lg),
              _buildToggleSetting(
                context: context,
                title: 'High Contrast Mode',
                subtitle: 'Improves text and button visibility',
                icon: Icons.contrast_rounded,
                value: accessibilityState.highContrastMode,
                onChanged: (value) {
                  ref
                      .read(accessibilitySettingsProvider.notifier)
                      .toggleHighContrast();
                },
              ),
            ],
          ),

          SizedBox(height: t.space.xxl),

          // Accessibility Settings Section
          _buildSection(
            context: context,
            title: 'Accessibility',
            icon: Icons.accessibility_rounded,
            children: [
              _buildToggleSetting(
                context: context,
                title: 'Reduce Animations',
                subtitle: 'Minimizes motion for users sensitive to movement',
                icon: Icons.motion_photos_off_rounded,
                value: accessibilityState.reduceAnimations,
                onChanged: (value) {
                  ref
                      .read(accessibilitySettingsProvider.notifier)
                      .toggleReduceAnimations();
                },
              ),
              SizedBox(height: t.space.lg),
              _buildTextScaleSetting(context, ref, accessibilityState),
            ],
          ),

          SizedBox(height: t.space.xxl),

          // Connection Settings Section
          _buildSection(
            context: context,
            title: 'Connection',
            icon: Icons.wifi_rounded,
            children: [
              _buildDeviceNameSetting(context, ref),
              SizedBox(height: t.space.lg),
              _buildInfoCard(
                context: context,
                title: 'Auto-Reconnect',
                subtitle: 'Automatically reconnects when connection is lost',
                icon: Icons.refresh_rounded,
                trailing: Icon(
                  Icons.check_circle_rounded,
                  color: t.color.success,
                ),
              ),
              SizedBox(height: t.space.md),
              _buildInfoCard(
                context: context,
                title: 'Connection Health Monitoring',
                subtitle: 'Continuously monitors connection quality',
                icon: Icons.health_and_safety_rounded,
                trailing: Icon(
                  Icons.check_circle_rounded,
                  color: t.color.success,
                ),
              ),
            ],
          ),

          SizedBox(height: t.space.xxl),

          // About Section
          _buildSection(
            context: context,
            title: 'About',
            icon: Icons.info_outline_rounded,
            children: [
              _buildInfoCard(
                context: context,
                title: 'MarcoDeck',
                subtitle: 'Remote Macro Control Application',
                icon: Icons.devices_rounded,
                trailing: Text(
                  'v1.0.0',
                  style: textTheme.bodySmall?.copyWith(
                    color: t.color.textMuted,
                  ),
                ),
              ),
              SizedBox(height: t.space.md),
              _buildInfoCard(
                context: context,
                title: 'Open Source',
                subtitle: 'Built with Flutter and open source technologies',
                icon: Icons.code_rounded,
                trailing: Icon(
                  Icons.open_in_new_rounded,
                  color: t.color.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: t.space.xs, bottom: t.space.md),
          child: Row(
            children: [
              Icon(icon, size: t.icon.lg, color: t.color.accent),
              SizedBox(width: t.space.sm),
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  color: t.color.accent,
                ),
              ),
            ],
          ),
        ),
        Card(
          child: Padding(
            padding: EdgeInsets.all(t.space.lg),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  Widget _buildOrientationSetting(
    BuildContext context,
    WidgetRef ref,
    DeckOrientation orientation,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final t = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Icon(
            Icons.screen_rotation_rounded,
            color: colorScheme.secondary,
          ),
          title: const Text(
            'Screen Orientation',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text('How the deck rotates with the device'),
          contentPadding: EdgeInsets.zero,
        ),
        SizedBox(height: t.space.sm),
        SegmentedButton<DeckOrientation>(
          segments: const [
            ButtonSegment(
              value: DeckOrientation.portrait,
              label: Text('Portrait'),
              icon: Icon(Icons.stay_current_portrait_rounded),
            ),
            ButtonSegment(
              value: DeckOrientation.landscape,
              label: Text('Landscape'),
              icon: Icon(Icons.stay_current_landscape_rounded),
            ),
            ButtonSegment(
              value: DeckOrientation.auto,
              label: Text('Auto'),
              icon: Icon(Icons.screen_rotation_alt_rounded),
            ),
          ],
          selected: {orientation},
          onSelectionChanged: (selection) {
            ref
                .read(deckOrientationProvider.notifier)
                .setOrientation(selection.first);
          },
        ),
      ],
    );
  }

  Widget _buildDeviceNameSetting(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final deviceName = ref.watch(deviceNameProvider);

    return ListTile(
      leading: Icon(Icons.devices_rounded, color: colorScheme.secondary),
      title: const Text(
        'Device Name',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(deviceName),
      trailing: IconButton(
        icon: const Icon(Icons.edit_rounded),
        onPressed: () => _showDeviceNameDialog(context, ref, deviceName),
        tooltip: 'Change device name',
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  Future<void> _showDeviceNameDialog(
    BuildContext context,
    WidgetRef ref,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Change Device Name'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Device Name',
                hintText: 'Enter a name for this device',
              ),
              maxLength: 30,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final newName = controller.text.trim();
                  if (newName.isNotEmpty) {
                    ref
                        .read(deviceNameProvider.notifier)
                        .setDeviceName(newName);
                    // Capture the messenger before popping the dialog so the
                    // snackbar is shown via the still-mounted parent scaffold.
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Device name changed to "$newName"'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );

    controller.dispose();
  }

  Widget _buildToggleSetting({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(icon, color: colorScheme.secondary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: Switch(value: value, onChanged: onChanged),
      onTap: () => onChanged(!value),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildTextScaleSetting(
    BuildContext context,
    WidgetRef ref,
    AccessibilityState state,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Icon(
            Icons.text_fields_rounded,
            color: colorScheme.secondary,
          ),
          title: const Text(
            'Text Size',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            'Adjust text size: ${(state.textScale * 100).round()}%',
          ),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.text_decrease_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
            Expanded(
              child: Slider(
                value: state.textScale,
                min: 0.8,
                max: 2.0,
                divisions: 12,
                label: '${(state.textScale * 100).round()}%',
                onChanged:
                    (value) => ref
                        .read(accessibilitySettingsProvider.notifier)
                        .setTextScale(value),
              ),
            ),
            Icon(
              Icons.text_increase_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    Widget? trailing,
  }) {
    final t = context.tokens;
    return ListTile(
      leading: Icon(icon, color: t.color.accent),
      title: Text(title, style: Theme.of(context).textTheme.titleSmall),
      subtitle: Text(subtitle),
      trailing: trailing,
      contentPadding: EdgeInsets.zero,
    );
  }
}
