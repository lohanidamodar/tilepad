import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Token-driven typography. A characterful geometric sans (Onest) for UI and a
/// mono (JetBrains Mono) for technical readouts. Built from [TypeScale] so sizes
/// and weights stay tokenized. Falls back to the system font offline.
class AppTypography {
  AppTypography._();

  static const TypeScale _t = TypeScale.base;

  /// Tests and screenshot tooling set this to skip google_fonts (which throws
  /// asynchronously when runtime fetching is disabled) and use locally
  /// registered families instead.
  @visibleForTesting
  static bool useSystemFonts = false;

  /// The display/UI font family resolver.
  static TextStyle _sans([TextStyle? base]) => useSystemFonts
      ? (base ?? const TextStyle()).copyWith(fontFamily: 'Roboto')
      : GoogleFonts.onest(textStyle: base);

  /// The monospace family used for IPs, ports, clocks and key combos.
  static TextStyle mono({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) =>
      useSystemFonts
          ? TextStyle(
              fontFamily: 'monospace',
              fontSize: fontSize ?? _t.mono,
              fontWeight: fontWeight ?? _t.wMedium,
              color: color,
              letterSpacing: 0,
            )
          : GoogleFonts.jetBrainsMono(
              fontSize: fontSize ?? _t.mono,
              fontWeight: fontWeight ?? _t.wMedium,
              color: color,
              letterSpacing: 0,
            );

  /// Builds the app [TextTheme] for the given [onSurface] color. Colors are
  /// applied by widgets/components; this sets the scale (size/weight/tracking).
  static TextTheme textTheme(Color onSurface) {
    TextStyle s(double size, FontWeight weight, double tracking,
            [double height = 1.25]) =>
        _sans(TextStyle(
          fontSize: size,
          fontWeight: weight,
          letterSpacing: tracking,
          height: height,
          color: onSurface,
        ));

    return TextTheme(
      // Display — used by hero/app titles.
      headlineMedium: s(_t.display, _t.wBold, -0.6, 1.15),
      headlineSmall: s(_t.title + 4, _t.wBold, -0.4, 1.18),
      // Titles
      titleLarge: s(_t.title, _t.wSemibold, -0.3, 1.2),
      titleMedium: s(_t.titleSm, _t.wSemibold, -0.2, 1.25),
      titleSmall: s(_t.body, _t.wSemibold, -0.1),
      // Body
      bodyLarge: s(_t.body, _t.wRegular, 0, 1.4),
      bodyMedium: s(_t.bodySm, _t.wRegular, 0, 1.4),
      bodySmall: s(_t.label, _t.wRegular, 0, 1.35),
      // Labels
      labelLarge: s(_t.bodySm, _t.wSemibold, 0),
      labelMedium: s(_t.label, _t.wMedium, 0.1),
      labelSmall: s(_t.labelSm, _t.wMedium, 0.2),
    );
  }
}
