import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Semantic color roles that go beyond Flutter's [ColorScheme]. Resolved per
/// brightness + accent in `app_theme.dart`.
@immutable
class MdkColors {
  final Color surface; // base background
  final Color surfaceSubtle; // slightly recessed (fills, inputs)
  final Color surfaceRaised; // cards, sheets
  final Color surfaceInverse; // tooltips, inverse chips
  final Color border; // hairline separators/outlines
  final Color borderStrong; // emphasized outlines, focus rings off-accent
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentSubtle; // tinted accent background
  final Color onAccent;
  final Color success, successSubtle;
  final Color warning, warningSubtle;
  final Color danger, dangerSubtle;
  final Color info, infoSubtle;
  final Color shadow; // shadow color (alpha already applied where used)
  final Color scrim;

  const MdkColors({
    required this.surface,
    required this.surfaceSubtle,
    required this.surfaceRaised,
    required this.surfaceInverse,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentSubtle,
    required this.onAccent,
    required this.success,
    required this.successSubtle,
    required this.warning,
    required this.warningSubtle,
    required this.danger,
    required this.dangerSubtle,
    required this.info,
    required this.infoSubtle,
    required this.shadow,
    required this.scrim,
  });

  static Color _c(Color a, Color b, double t) => Color.lerp(a, b, t)!;

  static MdkColors lerp(MdkColors a, MdkColors b, double t) => MdkColors(
        surface: _c(a.surface, b.surface, t),
        surfaceSubtle: _c(a.surfaceSubtle, b.surfaceSubtle, t),
        surfaceRaised: _c(a.surfaceRaised, b.surfaceRaised, t),
        surfaceInverse: _c(a.surfaceInverse, b.surfaceInverse, t),
        border: _c(a.border, b.border, t),
        borderStrong: _c(a.borderStrong, b.borderStrong, t),
        textPrimary: _c(a.textPrimary, b.textPrimary, t),
        textSecondary: _c(a.textSecondary, b.textSecondary, t),
        textMuted: _c(a.textMuted, b.textMuted, t),
        accent: _c(a.accent, b.accent, t),
        accentSubtle: _c(a.accentSubtle, b.accentSubtle, t),
        onAccent: _c(a.onAccent, b.onAccent, t),
        success: _c(a.success, b.success, t),
        successSubtle: _c(a.successSubtle, b.successSubtle, t),
        warning: _c(a.warning, b.warning, t),
        warningSubtle: _c(a.warningSubtle, b.warningSubtle, t),
        danger: _c(a.danger, b.danger, t),
        dangerSubtle: _c(a.dangerSubtle, b.dangerSubtle, t),
        info: _c(a.info, b.info, t),
        infoSubtle: _c(a.infoSubtle, b.infoSubtle, t),
        shadow: _c(a.shadow, b.shadow, t),
        scrim: _c(a.scrim, b.scrim, t),
      );
}

/// The shared design-system surface read by widgets via `context.tokens`.
///
/// Holds the semantic color set plus the (density-scaled) spacing scale and the
/// constant primitive scales, so every widget can resolve visual values from
/// one place. Implemented as a [ThemeExtension] so it animates with the theme.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  final MdkColors color;
  final SpaceScale space;
  final Radii radius;
  final IconSizes icon;
  final Borders border;
  final TypeScale typeScale;
  final Motion motion;
  final Opacities opacity;
  final AppDensity density;

  const AppTokens({
    required this.color,
    required this.space,
    this.radius = Radii.base,
    this.icon = IconSizes.base,
    this.border = Borders.base,
    this.typeScale = TypeScale.base,
    this.motion = Motion.base,
    this.opacity = Opacities.base,
    required this.density,
  });

  // --- Convenience builders (token-only, no magic numbers in widgets) ---

  /// Symmetric page padding that respects density.
  EdgeInsets get pagePadding => EdgeInsets.all(space.lg);

  /// A soft, sparing shadow for raised surfaces.
  List<BoxShadow> get shadowSm => [
        BoxShadow(
          color: color.shadow,
          blurRadius: space.sm,
          offset: Offset(0, space.xxs),
        ),
      ];

  List<BoxShadow> get shadowMd => [
        BoxShadow(
          color: color.shadow,
          blurRadius: space.lg,
          offset: Offset(0, space.xs),
        ),
      ];

  @override
  AppTokens copyWith({
    MdkColors? color,
    SpaceScale? space,
    Radii? radius,
    IconSizes? icon,
    Borders? border,
    TypeScale? typeScale,
    Motion? motion,
    Opacities? opacity,
    AppDensity? density,
  }) =>
      AppTokens(
        color: color ?? this.color,
        space: space ?? this.space,
        radius: radius ?? this.radius,
        icon: icon ?? this.icon,
        border: border ?? this.border,
        typeScale: typeScale ?? this.typeScale,
        motion: motion ?? this.motion,
        opacity: opacity ?? this.opacity,
        density: density ?? this.density,
      );

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      color: MdkColors.lerp(color, other.color, t),
      space: SpaceScale.lerp(space, other.space, t),
      radius: t < 0.5 ? radius : other.radius,
      icon: t < 0.5 ? icon : other.icon,
      border: t < 0.5 ? border : other.border,
      typeScale: t < 0.5 ? typeScale : other.typeScale,
      motion: t < 0.5 ? motion : other.motion,
      opacity: t < 0.5 ? opacity : other.opacity,
      density: t < 0.5 ? density : other.density,
    );
  }

  /// Linearly interpolates a double (exposed for widgets that animate sizes).
  static double lerpD(double a, double b, double t) => lerpDouble(a, b, t)!;
}

/// `context.tokens` — the ergonomic accessor for the design system.
extension TokenContext on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ?? _fallbackTokens(this);

  static AppTokens _fallbackTokens(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Minimal fallback if the extension is missing (should not happen in app).
    return AppTokens(
      density: AppDensity.comfortable,
      space: SpaceScale.base,
      color: MdkColors(
        surface: scheme.surface,
        surfaceSubtle: scheme.surfaceContainerHighest,
        surfaceRaised: scheme.surface,
        surfaceInverse: scheme.inverseSurface,
        border: scheme.outlineVariant,
        borderStrong: scheme.outline,
        textPrimary: scheme.onSurface,
        textSecondary: scheme.onSurfaceVariant,
        textMuted: scheme.onSurfaceVariant,
        accent: scheme.primary,
        accentSubtle: scheme.primaryContainer,
        onAccent: scheme.onPrimary,
        success: const Color(0xFF10B981),
        successSubtle: const Color(0x1A10B981),
        warning: const Color(0xFFF59E0B),
        warningSubtle: const Color(0x1AF59E0B),
        danger: scheme.error,
        dangerSubtle: scheme.errorContainer,
        info: scheme.primary,
        infoSubtle: scheme.primaryContainer,
        shadow: const Color(0x14000000),
        scrim: const Color(0x73000000),
      ),
    );
  }
}
