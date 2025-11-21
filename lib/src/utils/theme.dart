import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme constants for consistent styling
class AppTheme {
  // Border radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;
  static const double radiusXXLarge = 28.0;

  // Spacing
  static const double spaceXSmall = 4.0;
  static const double spaceSmall = 8.0;
  static const double spaceMedium = 12.0;
  static const double spaceLarge = 16.0;
  static const double spaceXLarge = 24.0;
  static const double spaceXXLarge = 32.0;

  // Elevation
  static const double elevationLow = 1.0;
  static const double elevationMedium = 2.0;
  static const double elevationHigh = 4.0;
}

/// Provider that manages the current theme mode
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// Notifier for theme mode
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _loadThemeMode();
    return ThemeMode.system;
  }

  /// Load theme mode from shared preferences
  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeString = prefs.getString('themeMode');
      if (themeModeString != null) {
        switch (themeModeString) {
          case 'light':
            state = ThemeMode.light;
            break;
          case 'dark':
            state = ThemeMode.dark;
            break;
          default:
            state = ThemeMode.system;
        }
      }
    } catch (e) {
      debugPrint('Error loading theme mode: $e');
    }
  }

  /// Set theme mode and save to shared preferences
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      switch (mode) {
        case ThemeMode.light:
          await prefs.setString('themeMode', 'light');
          break;
        case ThemeMode.dark:
          await prefs.setString('themeMode', 'dark');
          break;
        case ThemeMode.system:
          await prefs.setString('themeMode', 'system');
          break;
      }
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }
}

/// Widget for selecting theme mode
class ThemeModeSelector extends StatelessWidget {
  /// Creates a theme mode selector
  const ThemeModeSelector({
    super.key,
    required this.currentThemeMode,
    required this.onThemeModeChanged,
  });

  /// Current theme mode
  final ThemeMode currentThemeMode;

  /// Callback for when theme mode is changed
  final Function(ThemeMode) onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<ThemeMode>(
      tooltip: 'Change theme',
      icon: Icon(
        _getThemeModeIcon(currentThemeMode),
        color: colorScheme.onSurfaceVariant,
      ),
      onSelected: onThemeModeChanged,
      position: PopupMenuPosition.under,
      itemBuilder:
          (BuildContext context) => <PopupMenuEntry<ThemeMode>>[
            PopupMenuItem<ThemeMode>(
              value: ThemeMode.light,
              child: ListTile(
                leading: Icon(
                  Icons.wb_sunny_outlined,
                  color:
                      currentThemeMode == ThemeMode.light
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                ),
                title: const Text('Light'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                selected: currentThemeMode == ThemeMode.light,
              ),
            ),
            PopupMenuItem<ThemeMode>(
              value: ThemeMode.dark,
              child: ListTile(
                leading: Icon(
                  Icons.nightlight_outlined,
                  color:
                      currentThemeMode == ThemeMode.dark
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                ),
                title: const Text('Dark'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                selected: currentThemeMode == ThemeMode.dark,
              ),
            ),
            PopupMenuItem<ThemeMode>(
              value: ThemeMode.system,
              child: ListTile(
                leading: Icon(
                  Icons.settings_suggest_outlined,
                  color:
                      currentThemeMode == ThemeMode.system
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                ),
                title: const Text('System'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                selected: currentThemeMode == ThemeMode.system,
              ),
            ),
          ],
    );
  }

  IconData _getThemeModeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.wb_sunny_outlined;
      case ThemeMode.dark:
        return Icons.nightlight_outlined;
      case ThemeMode.system:
        return Icons.settings_suggest_outlined;
    }
  }
}

/// Common theme extensions
/// Light theme for the app
ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF6366F1), // Modern indigo
    brightness: Brightness.light,
  ).copyWith(
    surface: const Color(0xFFFCFCFC),
    surfaceContainerHighest: const Color(0xFFF3F4F6),
    surfaceContainer: const Color(0xFFF9FAFB),
  ),
  scaffoldBackgroundColor: const Color(0xFFFCFCFC),
  appBarTheme: const AppBarTheme(
    centerTitle: false,
    elevation: 0,
    scrolledUnderElevation: 0,
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
  ),
  cardTheme: CardThemeData(
    clipBehavior: Clip.antiAlias,
    elevation: 0,
    shadowColor: Colors.transparent,
    margin: const EdgeInsets.all(AppTheme.spaceSmall),
    color: const Color(0xFFFFFFFF),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      side: BorderSide(color: const Color(0xFFE5E7EB), width: 1),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFF9FAFB),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppTheme.spaceLarge,
      vertical: AppTheme.spaceLarge,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceXLarge,
        vertical: AppTheme.spaceLarge,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      elevation: 0,
      shadowColor: Colors.transparent,
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceXLarge,
        vertical: AppTheme.spaceLarge,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      elevation: 0,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceLarge,
        vertical: AppTheme.spaceMedium,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceXLarge,
        vertical: AppTheme.spaceLarge,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      side: const BorderSide(width: 1.5, color: Color(0xFFE5E7EB)),
    ),
  ),
  dialogTheme: DialogThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusXXLarge),
    ),
    elevation: AppTheme.elevationHigh,
    shadowColor: Colors.black.withValues(alpha: 0.08),
    surfaceTintColor: Colors.transparent,
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
    ),
    elevation: AppTheme.elevationMedium,
  ),
  chipTheme: ChipThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
    ),
    elevation: 0,
    side: const BorderSide(color: Color(0xFFE5E7EB)),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
    ),
    elevation: AppTheme.elevationMedium,
  ),
  listTileTheme: ListTileThemeData(
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppTheme.spaceLarge,
      vertical: AppTheme.spaceXSmall,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
    ),
  ),
  switchTheme: SwitchThemeData(
    thumbIcon: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const Icon(Icons.check, size: 14);
      }
      return null;
    }),
  ),
  dividerTheme: DividerThemeData(
    space: 1,
    thickness: 1,
    color: const Color(0xFFE5E7EB).withValues(alpha: 0.6),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    circularTrackColor: Color(0xFFE5E7EB),
  ),
);

/// Dark theme for the app
ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF6366F1), // Modern indigo
    brightness: Brightness.dark,
  ).copyWith(
    surface: const Color(0xFF1C1C1E),
    surfaceContainerHighest: const Color(0xFF2C2C2E),
    surfaceContainer: const Color(0xFF242426),
  ),
  scaffoldBackgroundColor: const Color(0xFF1C1C1E),
  appBarTheme: const AppBarTheme(
    centerTitle: false,
    elevation: 0,
    scrolledUnderElevation: 0,
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
  ),
  cardTheme: CardThemeData(
    clipBehavior: Clip.antiAlias,
    elevation: 0,
    shadowColor: Colors.transparent,
    margin: const EdgeInsets.all(AppTheme.spaceSmall),
    color: const Color(0xFF242426),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      side: BorderSide(color: const Color(0xFF3A3A3C), width: 1),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF2C2C2E),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      borderSide: const BorderSide(color: Color(0xFF3A3A3C)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      borderSide: const BorderSide(color: Color(0xFF3A3A3C)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      borderSide: const BorderSide(color: Color(0xFF818CF8), width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      borderSide: const BorderSide(color: Color(0xFFF87171), width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      borderSide: const BorderSide(color: Color(0xFFF87171), width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppTheme.spaceLarge,
      vertical: AppTheme.spaceLarge,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceXLarge,
        vertical: AppTheme.spaceLarge,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      elevation: 0,
      shadowColor: Colors.transparent,
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceXLarge,
        vertical: AppTheme.spaceLarge,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      elevation: 0,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceLarge,
        vertical: AppTheme.spaceMedium,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceXLarge,
        vertical: AppTheme.spaceLarge,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      side: const BorderSide(width: 1.5, color: Color(0xFF3A3A3C)),
    ),
  ),
  dialogTheme: DialogThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusXXLarge),
    ),
    elevation: AppTheme.elevationHigh,
    shadowColor: Colors.black.withValues(alpha: 0.3),
    surfaceTintColor: Colors.transparent,
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
    ),
    elevation: AppTheme.elevationMedium,
  ),
  chipTheme: ChipThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
    ),
    elevation: 0,
    side: const BorderSide(color: Color(0xFF3A3A3C)),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
    ),
    elevation: AppTheme.elevationMedium,
  ),
  listTileTheme: ListTileThemeData(
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppTheme.spaceLarge,
      vertical: AppTheme.spaceXSmall,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
    ),
  ),
  switchTheme: SwitchThemeData(
    thumbIcon: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const Icon(Icons.check, size: 14);
      }
      return null;
    }),
  ),
  dividerTheme: DividerThemeData(
    space: 1,
    thickness: 1,
    color: const Color(0xFF3A3A3C).withValues(alpha: 0.6),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    circularTrackColor: Color(0xFF3A3A3C),
  ),
);
