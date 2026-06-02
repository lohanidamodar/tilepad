import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'app_typography.dart';
import 'tokens.dart';

/// Builds a fully token-driven [ThemeData] for a given brightness, accent and
/// density. Every component theme derives from tokens — no hardcoded values
/// leak into widgets, and the [AppTokens] extension is attached for semantic
/// roles read via `context.tokens`.
ThemeData buildAppTheme({
  required Brightness brightness,
  required AccentOption accent,
  required AppDensity density,
}) {
  final isDark = brightness == Brightness.dark;
  final space = SpaceScale.base.scaled(density.spaceFactor);
  const radius = Radii.base;
  const borders = Borders.base;
  const icons = IconSizes.base;

  final colors = _colors(isDark: isDark, accent: accent.seed);
  final scheme = _scheme(brightness, accent.seed, colors);
  final tokens = AppTokens(
    color: colors,
    space: space,
    radius: radius,
    border: borders,
    icon: icons,
    density: density,
  );
  final text = AppTypography.textTheme(colors.textPrimary);

  OutlineInputBorder inputBorder(Color c, double w) => OutlineInputBorder(
        borderRadius: radius.brMd,
        borderSide: BorderSide(color: c, width: w),
      );

  ButtonStyle pad(EdgeInsets p) => ButtonStyle(
        padding: WidgetStatePropertyAll(p),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: radius.brMd),
        ),
        elevation: const WidgetStatePropertyAll(0),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
      );

  final btnPadding =
      EdgeInsets.symmetric(horizontal: space.xl, vertical: space.md);
  final btnPaddingSm =
      EdgeInsets.symmetric(horizontal: space.lg, vertical: space.sm);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.surface,
    canvasColor: colors.surface,
    visualDensity: density.visualDensity,
    splashFactory: InkSparkle.splashFactory,
    extensions: [tokens],
    textTheme: text,
    iconTheme: IconThemeData(color: colors.textSecondary, size: icons.lg),
    primaryColor: colors.accent,
    dividerColor: colors.border,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: colors.textPrimary,
      titleTextStyle: text.titleLarge,
      iconTheme: IconThemeData(color: colors.textSecondary, size: icons.lg),
      titleSpacing: space.lg,
    ),
    cardTheme: CardThemeData(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shadowColor: Colors.transparent,
      margin: EdgeInsets.all(space.sm),
      color: colors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: radius.brLg,
        side: BorderSide(color: colors.border, width: borders.hairline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceSubtle,
      isDense: density == AppDensity.compact,
      hintStyle: text.bodyMedium?.copyWith(color: colors.textMuted),
      labelStyle: text.bodyMedium?.copyWith(color: colors.textSecondary),
      border: inputBorder(colors.border, borders.hairline),
      enabledBorder: inputBorder(colors.border, borders.hairline),
      focusedBorder: inputBorder(colors.accent, borders.focus),
      errorBorder: inputBorder(colors.danger, borders.hairline),
      focusedErrorBorder: inputBorder(colors.danger, borders.focus),
      contentPadding:
          EdgeInsets.symmetric(horizontal: space.md, vertical: space.md),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: pad(btnPadding).copyWith(
        backgroundColor: WidgetStatePropertyAll(colors.accent),
        foregroundColor: WidgetStatePropertyAll(colors.onAccent),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: pad(btnPadding).copyWith(
        backgroundColor: WidgetStatePropertyAll(colors.surfaceRaised),
        foregroundColor: WidgetStatePropertyAll(colors.textPrimary),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        side: WidgetStatePropertyAll(
          BorderSide(color: colors.border, width: borders.hairline),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: pad(btnPaddingSm).copyWith(
        foregroundColor: WidgetStatePropertyAll(colors.accent),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: pad(btnPadding).copyWith(
        foregroundColor: WidgetStatePropertyAll(colors.textPrimary),
        side: WidgetStatePropertyAll(
          BorderSide(color: colors.borderStrong, width: borders.hairline),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(colors.textSecondary),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: radius.brSm),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: radius.brXl,
        side: BorderSide(color: colors.border, width: borders.hairline),
      ),
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyMedium?.copyWith(color: colors.textSecondary),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colors.surfaceInverse,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: isDark ? colors.textPrimary : colors.surface,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: radius.brMd),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.surfaceSubtle,
      side: BorderSide(color: colors.border, width: borders.hairline),
      labelStyle: text.labelMedium,
      shape: RoundedRectangleBorder(borderRadius: radius.brSm),
      padding: EdgeInsets.symmetric(horizontal: space.sm, vertical: space.xxs),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colors.accent,
      foregroundColor: colors.onAccent,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(borderRadius: radius.brLg),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding:
          EdgeInsets.symmetric(horizontal: space.lg, vertical: space.xxs),
      iconColor: colors.textSecondary,
      textColor: colors.textPrimary,
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodyMedium?.copyWith(color: colors.textSecondary),
      shape: RoundedRectangleBorder(borderRadius: radius.brMd),
    ),
    switchTheme: SwitchThemeData(
      thumbIcon: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Icon(Icons.check, size: icons.xs, color: colors.onAccent);
        }
        return null;
      }),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(text.labelMedium),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: radius.brSm),
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      textStyle: text.bodyMedium,
      shape: RoundedRectangleBorder(
        borderRadius: radius.brMd,
        side: BorderSide(color: colors.border, width: borders.hairline),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: colors.surfaceInverse,
        borderRadius: radius.brSm,
      ),
      textStyle: text.labelMedium?.copyWith(
        color: isDark ? colors.textPrimary : colors.surface,
      ),
      padding: EdgeInsets.symmetric(horizontal: space.sm, vertical: space.xs),
    ),
    dividerTheme: DividerThemeData(
      space: borders.hairline,
      thickness: borders.hairline,
      color: colors.border,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.accent,
      circularTrackColor: colors.surfaceSubtle,
      linearTrackColor: colors.surfaceSubtle,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: colors.accentSubtle,
      elevation: 0,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: icons.lg,
          color: s.contains(WidgetState.selected)
              ? colors.accent
              : colors.textSecondary,
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius.xl)),
      ),
    ),
  );
}

/// Semantic colors per brightness, tinted by the [accent] seed.
MdkColors _colors({required bool isDark, required Color accent}) {
  final scrim = isDark ? const Color(0x99000000) : const Color(0x66000000);
  if (isDark) {
    return MdkColors(
      surface: const Color(0xFF0F1115),
      surfaceSubtle: const Color(0xFF16181D),
      surfaceRaised: const Color(0xFF1B1E24),
      surfaceInverse: const Color(0xFFECEEF2),
      border: const Color(0xFF282C34),
      borderStrong: const Color(0xFF3A3F4B),
      textPrimary: const Color(0xFFECEEF2),
      textSecondary: const Color(0xFFA8AEBA),
      textMuted: const Color(0xFF6E7480),
      accent: accent,
      accentSubtle: accent.withValues(alpha: 0.18),
      onAccent: Colors.white,
      success: const Color(0xFF34D399),
      successSubtle: const Color(0xFF34D399).withValues(alpha: 0.16),
      warning: const Color(0xFFFBBF24),
      warningSubtle: const Color(0xFFFBBF24).withValues(alpha: 0.16),
      danger: const Color(0xFFFB7185),
      dangerSubtle: const Color(0xFFFB7185).withValues(alpha: 0.16),
      info: const Color(0xFF60A5FA),
      infoSubtle: const Color(0xFF60A5FA).withValues(alpha: 0.16),
      shadow: const Color(0x66000000),
      scrim: scrim,
    );
  }
  return MdkColors(
    surface: const Color(0xFFFCFCFD),
    surfaceSubtle: const Color(0xFFF3F4F6),
    surfaceRaised: const Color(0xFFFFFFFF),
    surfaceInverse: const Color(0xFF1B1E24),
    border: const Color(0xFFE6E8EC),
    borderStrong: const Color(0xFFD3D7DE),
    textPrimary: const Color(0xFF16181D),
    textSecondary: const Color(0xFF5C6370),
    textMuted: const Color(0xFF8A909C),
    accent: accent,
    accentSubtle: accent.withValues(alpha: 0.12),
    onAccent: Colors.white,
    success: const Color(0xFF059669),
    successSubtle: const Color(0xFF059669).withValues(alpha: 0.12),
    warning: const Color(0xFFD97706),
    warningSubtle: const Color(0xFFD97706).withValues(alpha: 0.12),
    danger: const Color(0xFFDC2626),
    dangerSubtle: const Color(0xFFDC2626).withValues(alpha: 0.10),
    info: const Color(0xFF2563EB),
    infoSubtle: const Color(0xFF2563EB).withValues(alpha: 0.10),
    shadow: const Color(0x14000000),
    scrim: scrim,
  );
}

/// A [ColorScheme] seeded from the accent and harmonised with our neutrals so
/// stock Material widgets match the token surfaces.
ColorScheme _scheme(Brightness b, Color accent, MdkColors c) =>
    ColorScheme.fromSeed(seedColor: accent, brightness: b).copyWith(
      primary: c.accent,
      onPrimary: c.onAccent,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surfaceSubtle,
      surfaceContainer: c.surfaceSubtle,
      surfaceContainerHigh: c.surfaceRaised,
      surfaceContainerHighest: c.surfaceRaised,
      outline: c.borderStrong,
      outlineVariant: c.border,
      error: c.danger,
      inverseSurface: c.surfaceInverse,
    );
