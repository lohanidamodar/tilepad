import 'package:flutter/material.dart';

/// Primitive design tokens: raw, theme-invariant scales shared by the client
/// and server. Theme-dependent (color) tokens live in `AppTokens`
/// (`app_tokens.dart`). UI code never hardcodes these values — it reads them
/// from here or from `context.tokens`.

/// Spacing scale on a 4px grid. Density-scaled instances are exposed via
/// `context.tokens.space`; the raw values live here.
@immutable
class SpaceScale {
  final double none, xxs, xs, sm, md, lg, xl, xxl, xxxl, huge;
  const SpaceScale({
    required this.none,
    required this.xxs,
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
    required this.xxxl,
    required this.huge,
  });

  /// The base (comfortable) spacing scale.
  static const SpaceScale base = SpaceScale(
    none: 0,
    xxs: 2,
    xs: 4,
    sm: 8,
    md: 12,
    lg: 16,
    xl: 20,
    xxl: 24,
    xxxl: 32,
    huge: 48,
  );

  /// Returns this scale multiplied by [factor] (used for density).
  SpaceScale scaled(double factor) => SpaceScale(
        none: 0,
        xxs: xxs * factor,
        xs: xs * factor,
        sm: sm * factor,
        md: md * factor,
        lg: lg * factor,
        xl: xl * factor,
        xxl: xxl * factor,
        xxxl: xxxl * factor,
        huge: huge * factor,
      );

  static SpaceScale lerp(SpaceScale a, SpaceScale b, double t) => SpaceScale(
        none: 0,
        xxs: _d(a.xxs, b.xxs, t),
        xs: _d(a.xs, b.xs, t),
        sm: _d(a.sm, b.sm, t),
        md: _d(a.md, b.md, t),
        lg: _d(a.lg, b.lg, t),
        xl: _d(a.xl, b.xl, t),
        xxl: _d(a.xxl, b.xxl, t),
        xxxl: _d(a.xxxl, b.xxxl, t),
        huge: _d(a.huge, b.huge, t),
      );

  static double _d(double a, double b, double t) => a + (b - a) * t;
}

/// Corner radius scale.
@immutable
class Radii {
  final double xs, sm, md, lg, xl, full;
  const Radii({
    this.xs = 6,
    this.sm = 8,
    this.md = 12,
    this.lg = 16,
    this.xl = 22,
    this.full = 999,
  });
  static const Radii base = Radii();

  BorderRadius get brXs => BorderRadius.circular(xs);
  BorderRadius get brSm => BorderRadius.circular(sm);
  BorderRadius get brMd => BorderRadius.circular(md);
  BorderRadius get brLg => BorderRadius.circular(lg);
  BorderRadius get brXl => BorderRadius.circular(xl);
}

/// Icon size scale.
@immutable
class IconSizes {
  final double xs, sm, md, lg, xl;
  const IconSizes({
    this.xs = 14,
    this.sm = 16,
    this.md = 18,
    this.lg = 20,
    this.xl = 24,
  });
  static const IconSizes base = IconSizes();
}

/// Border widths.
@immutable
class Borders {
  final double hairline, strong, focus;
  const Borders({this.hairline = 1, this.strong = 1.5, this.focus = 2});
  static const Borders base = Borders();
}

/// Opacity tokens for layering and states.
@immutable
class Opacities {
  final double disabled, muted, subtle, hover, pressed, scrim, divider;
  const Opacities({
    this.disabled = 0.38,
    this.muted = 0.62,
    this.subtle = 0.10,
    this.hover = 0.08,
    this.pressed = 0.12,
    this.scrim = 0.45,
    this.divider = 0.55,
  });
  static const Opacities base = Opacities();
}

/// Motion tokens.
@immutable
class Motion {
  final Duration fast, normal, slow;
  final Curve standard, emphasized, decelerate;
  const Motion({
    this.fast = const Duration(milliseconds: 120),
    this.normal = const Duration(milliseconds: 200),
    this.slow = const Duration(milliseconds: 320),
    this.standard = Curves.easeInOutCubic,
    this.emphasized = Curves.easeOutCubic,
    this.decelerate = Curves.decelerate,
  });
  static const Motion base = Motion();
}

/// Type scale: sizes, weights, tracking and line heights. Concrete `TextStyle`s
/// are built in `app_typography.dart`.
@immutable
class TypeScale {
  // Sizes
  final double display, title, titleSm, body, bodySm, label, labelSm, mono;
  // Weights
  final FontWeight wRegular, wMedium, wSemibold, wBold;
  const TypeScale({
    this.display = 28,
    this.title = 18,
    this.titleSm = 15,
    this.body = 14,
    this.bodySm = 13,
    this.label = 12,
    this.labelSm = 11,
    this.mono = 13,
    this.wRegular = FontWeight.w400,
    this.wMedium = FontWeight.w500,
    this.wSemibold = FontWeight.w600,
    this.wBold = FontWeight.w700,
  });
  static const TypeScale base = TypeScale();
}

/// A selectable accent identity (drives the seed color + a fixed swatch shown
/// in the personalization picker).
@immutable
class AccentOption {
  final String id;
  final String label;
  final Color seed;
  const AccentOption(this.id, this.label, this.seed);
}

/// Curated accent palette for personalization.
class AccentPalette {
  AccentPalette._();
  static const indigo = AccentOption('indigo', 'Indigo', Color(0xFF6366F1));
  static const blue = AccentOption('blue', 'Blue', Color(0xFF3B82F6));
  static const teal = AccentOption('teal', 'Teal', Color(0xFF14B8A6));
  static const emerald = AccentOption('emerald', 'Emerald', Color(0xFF10B981));
  static const amber = AccentOption('amber', 'Amber', Color(0xFFF59E0B));
  static const rose = AccentOption('rose', 'Rose', Color(0xFFF43F5E));
  static const violet = AccentOption('violet', 'Violet', Color(0xFF8B5CF6));
  static const slate = AccentOption('slate', 'Slate', Color(0xFF64748B));

  static const List<AccentOption> all = [
    indigo,
    blue,
    teal,
    emerald,
    amber,
    rose,
    violet,
    slate,
  ];

  static AccentOption byId(String id) =>
      all.firstWhere((a) => a.id == id, orElse: () => indigo);
}

/// UI density options for personalization.
enum AppDensity {
  comfortable,
  compact;

  /// Spacing multiplier applied to the spacing scale.
  double get spaceFactor => this == AppDensity.compact ? 0.82 : 1.0;

  /// Material [VisualDensity] derived from the density.
  VisualDensity get visualDensity => this == AppDensity.compact
      ? const VisualDensity(horizontal: -2, vertical: -2)
      : VisualDensity.standard;
}
