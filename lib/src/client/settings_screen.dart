import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/accessibility.dart';
import '../utils/theme.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accessibilityState = ref.watch(accessibilitySettingsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final keepAwake = ref.watch(keepAwakeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.settings_rounded, color: colorScheme.primary),
            const SizedBox(width: 12),
            const Text('Settings'),
          ],
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        children: [
          // Display Settings Section
          _buildSection(
            context: context,
            title: 'Display',
            icon: Icons.display_settings_rounded,
            children: [
              _buildThemeSelector(context, ref, themeMode),
              const SizedBox(height: AppTheme.spaceLarge),
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
              const SizedBox(height: AppTheme.spaceLarge),
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

          const SizedBox(height: AppTheme.spaceXLarge),

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
              const SizedBox(height: 16),
              _buildTextScaleSetting(context, ref, accessibilityState),
            ],
          ),

          const SizedBox(height: AppTheme.spaceXLarge),

          // Connection Settings Section
          _buildSection(
            context: context,
            title: 'Connection',
            icon: Icons.wifi_rounded,
            children: [
              _buildDeviceNameSetting(context, ref),
              const SizedBox(height: 16),
              _buildInfoCard(
                context: context,
                title: 'Auto-Reconnect',
                subtitle: 'Automatically reconnects when connection is lost',
                icon: Icons.refresh_rounded,
                trailing: Icon(Icons.check_circle_rounded, color: Colors.green),
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                context: context,
                title: 'Connection Health Monitoring',
                subtitle: 'Continuously monitors connection quality',
                icon: Icons.health_and_safety_rounded,
                trailing: Icon(Icons.check_circle_rounded, color: Colors.green),
              ),
            ],
          ),

          const SizedBox(height: 24),

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
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                context: context,
                title: 'Open Source',
                subtitle: 'Built with Flutter and open source technologies',
                icon: Icons.code_rounded,
                trailing: Icon(
                  Icons.open_in_new_rounded,
                  color: colorScheme.primary,
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: colorScheme.primary),
              const SizedBox(width: AppTheme.spaceSmall),
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceLarge),
            child: Column(children: children),
          ),
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

    return showDialog(
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
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
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

  Widget _buildThemeSelector(
    BuildContext context,
    WidgetRef ref,
    ThemeMode themeMode,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Icon(Icons.palette_rounded, color: colorScheme.secondary),
          title: const Text(
            'Theme',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(_getThemeModeLabel(themeMode)),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildThemeOption(
                context: context,
                label: 'Light',
                icon: Icons.wb_sunny_rounded,
                isSelected: themeMode == ThemeMode.light,
                onTap:
                    () => ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(ThemeMode.light),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildThemeOption(
                context: context,
                label: 'Dark',
                icon: Icons.nightlight_rounded,
                isSelected: themeMode == ThemeMode.dark,
                onTap:
                    () => ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(ThemeMode.dark),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildThemeOption(
                context: context,
                label: 'System',
                icon: Icons.settings_suggest_rounded,
                isSelected: themeMode == ThemeMode.system,
                onTap:
                    () => ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(ThemeMode.system),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color:
          isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.spaceMedium,
            horizontal: AppTheme.spaceSmall,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color:
                    isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppTheme.spaceXSmall),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color:
                      isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(icon, color: colorScheme.secondary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: trailing,
      contentPadding: EdgeInsets.zero,
    );
  }

  String _getThemeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light theme';
      case ThemeMode.dark:
        return 'Dark theme';
      case ThemeMode.system:
        return 'Follow system setting';
    }
  }
}
