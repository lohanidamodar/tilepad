import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// A quiet, compact titled section used by editor and settings screens.
///
/// One consistent pattern: a hairline-bordered card with a small header row
/// (optional leading icon, title, optional trailing control) and an optional
/// one-line subtitle, followed by the section's content. Replaces the older
/// mix of solid accent-filled headers and ad-hoc cards so screens stay
/// minimal and visually consistent.
class SectionCard extends StatelessWidget {
  /// Small leading icon rendered in the accent color.
  final IconData? icon;

  /// Section title.
  final String title;

  /// Optional supporting line under the header.
  final String? subtitle;

  /// Optional control aligned to the end of the header row (e.g. a [Switch]
  /// or an add button).
  final Widget? trailing;

  /// Section content, laid out in a column below the header.
  final List<Widget> children;

  /// When true the children span the card's full width with no horizontal
  /// padding — for embedded lists that draw their own item insets.
  final bool flush;

  const SectionCard({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.children = const [],
    this.flush = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    final header = Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: t.icon.md, color: t.color.accent),
          SizedBox(width: t.space.sm),
        ],
        Expanded(
          child: Text(
            title,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: t.typeScale.wSemibold,
            ),
          ),
        ),
        ?trailing,
      ],
    );

    // A Material (not a decorated Container) so descendant ListTiles and
    // InkWells paint their ink on this card.
    return Material(
      color: t.color.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: t.radius.brMd,
        side: BorderSide(color: t.color.border, width: t.border.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              t.space.lg,
              // The trailing control (button/switch) carries its own height;
              // tighten the top so headers with and without one match.
              trailing == null ? t.space.lg : t.space.sm,
              trailing == null ? t.space.lg : t.space.sm,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                if (subtitle != null) ...[
                  SizedBox(height: t.space.xs),
                  Padding(
                    // Align the subtitle with the title when an icon leads.
                    padding: EdgeInsets.only(
                      right: t.space.sm,
                    ),
                    child: Text(
                      subtitle!,
                      style: textTheme.bodySmall?.copyWith(
                        color: t.color.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (children.isEmpty)
            SizedBox(height: t.space.lg)
          else if (flush) ...[
            SizedBox(height: t.space.md),
            ...children,
            SizedBox(height: t.space.sm),
          ] else
            Padding(
              padding: EdgeInsets.fromLTRB(
                t.space.lg,
                t.space.md,
                t.space.lg,
                t.space.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
        ],
      ),
    );
  }
}
