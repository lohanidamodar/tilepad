import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_tokens.dart';
import 'personalization.dart';
import 'tokens.dart';

/// A shared, self-contained appearance picker (theme mode, accent, density)
/// used by both the client Settings and the server. Reads/writes
/// [personalizationProvider], so it stays in sync everywhere on the device.
class PersonalizationPanel extends ConsumerWidget {
  const PersonalizationPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(personalizationProvider);
    final notifier = ref.read(personalizationProvider.notifier);
    final t = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: 'Theme'),
        SizedBox(height: t.space.sm),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode_outlined),
              label: Text('Light'),
            ),
            ButtonSegment(
              value: ThemeMode.system,
              icon: Icon(Icons.brightness_auto_outlined),
              label: Text('Auto'),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode_outlined),
              label: Text('Dark'),
            ),
          ],
          selected: {p.themeMode},
          showSelectedIcon: false,
          onSelectionChanged: (s) => notifier.setThemeMode(s.first),
        ),
        SizedBox(height: t.space.xl),
        _SectionLabel(text: 'Accent'),
        SizedBox(height: t.space.sm),
        Wrap(
          spacing: t.space.sm,
          runSpacing: t.space.sm,
          children: [
            for (final accent in AccentPalette.all)
              _AccentSwatch(
                accent: accent,
                selected: accent.id == p.accentId,
                onTap: () => notifier.setAccent(accent.id),
              ),
          ],
        ),
        SizedBox(height: t.space.xl),
        _SectionLabel(text: 'Density'),
        SizedBox(height: t.space.sm),
        SegmentedButton<AppDensity>(
          segments: const [
            ButtonSegment(
              value: AppDensity.comfortable,
              icon: Icon(Icons.density_medium_outlined),
              label: Text('Comfortable'),
            ),
            ButtonSegment(
              value: AppDensity.compact,
              icon: Icon(Icons.density_small_outlined),
              label: Text('Compact'),
            ),
          ],
          selected: {p.density},
          showSelectedIcon: false,
          onSelectionChanged: (s) => notifier.setDensity(s.first),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: t.color.textMuted,
            letterSpacing: 0.8,
          ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  final AccentOption accent;
  final bool selected;
  final VoidCallback onTap;
  const _AccentSwatch({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final size = t.space.xxxl;
    return Tooltip(
      message: accent.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: t.radius.brSm,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: accent.seed,
            borderRadius: t.radius.brSm,
            border: Border.all(
              color: selected ? t.color.textPrimary : t.color.border,
              width: selected ? t.border.strong : t.border.hairline,
            ),
          ),
          child: selected
              ? Icon(Icons.check, color: Colors.white, size: t.icon.md)
              : null,
        ),
      ),
    );
  }
}
