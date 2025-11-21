import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
const _commonBorderRadius = 12.0;
const _cardBorderRadius = 16.0;
const _fabBorderRadius = 16.0;

/// Light theme for the app
ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF0353A4),
    brightness: Brightness.light,
  ),
  appBarTheme: AppBarTheme(
    centerTitle: false,
    elevation: 0,
    scrolledUnderElevation: 1,
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
  ),
  cardTheme: CardThemeData(
    clipBehavior: Clip.antiAlias,
    elevation: 2,
    shadowColor: Colors.black.withValues(alpha: 0.1),
    margin: const EdgeInsets.all(8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_cardBorderRadius),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.grey.shade50,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_commonBorderRadius),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_commonBorderRadius),
      borderSide: const BorderSide(color: Color(0xFF0353A4), width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_commonBorderRadius),
      borderSide: const BorderSide(color: Colors.red, width: 2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_commonBorderRadius),
      borderSide: const BorderSide(color: Colors.red, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_commonBorderRadius),
      ),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.1),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_commonBorderRadius),
      ),
      elevation: 0,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_commonBorderRadius),
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_commonBorderRadius),
      ),
    ),
  ),
  dialogTheme: DialogThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_cardBorderRadius),
    ),
    elevation: 8,
    shadowColor: Colors.black.withValues(alpha: 0.2),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_commonBorderRadius),
    ),
    elevation: 4,
  ),
  chipTheme: ChipThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    elevation: 0,
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_fabBorderRadius),
    ),
    elevation: 3,
  ),
  listTileTheme: const ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(horizontal: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
  ),
  switchTheme: SwitchThemeData(
    thumbIcon: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const Icon(Icons.check, color: Colors.white, size: 12);
      }
      return const Icon(Icons.close, color: Colors.white, size: 12);
    }),
  ),
  dividerTheme: const DividerThemeData(space: 1, thickness: 1),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    linearTrackColor: Colors.grey,
    circularTrackColor: Colors.grey,
  ),
);

/// Dark theme for the app
ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF0353A4),
    brightness: Brightness.dark,
  ),
  appBarTheme: AppBarTheme(
    centerTitle: false,
    elevation: 0,
    scrolledUnderElevation: 1,
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
  ),
  cardTheme: CardThemeData(
    clipBehavior: Clip.antiAlias,
    elevation: 2,
    shadowColor: Colors.black.withValues(alpha: 0.3),
    margin: const EdgeInsets.all(8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_cardBorderRadius),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.grey.shade900,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_commonBorderRadius),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_commonBorderRadius),
      borderSide: const BorderSide(color: Color(0xFF0353A4), width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_commonBorderRadius),
      borderSide: const BorderSide(color: Colors.red, width: 2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_commonBorderRadius),
      borderSide: const BorderSide(color: Colors.red, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_commonBorderRadius),
      ),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.3),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_commonBorderRadius),
      ),
      elevation: 0,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_commonBorderRadius),
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_commonBorderRadius),
      ),
    ),
  ),
  dialogTheme: DialogThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_cardBorderRadius),
    ),
    elevation: 8,
    shadowColor: Colors.black.withValues(alpha: 0.4),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_commonBorderRadius),
    ),
    elevation: 4,
  ),
  chipTheme: ChipThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    elevation: 0,
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_fabBorderRadius),
    ),
    elevation: 3,
  ),
  listTileTheme: const ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(horizontal: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
  ),
  switchTheme: SwitchThemeData(
    thumbIcon: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const Icon(Icons.check, color: Colors.white, size: 12);
      }
      return const Icon(Icons.close, color: Colors.white, size: 12);
    }),
  ),
  dividerTheme: const DividerThemeData(space: 1, thickness: 1),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    linearTrackColor: Colors.grey,
    circularTrackColor: Colors.grey,
  ),
);
