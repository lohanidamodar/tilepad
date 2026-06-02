import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'splash_screen.dart';
import 'settings_screen.dart';
import 'client_providers.dart' as providers;
import '../utils/accessibility.dart';
import '../utils/theme.dart';

/// Main entry point for the client app
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait orientation for the client app
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Keep the screen awake while the app is running
  WakelockPlus.enable();

  runApp(const ProviderScope(child: MarcoDeckClientApp()));
}

/// The MarcoDeck client application
class MarcoDeckClientApp extends ConsumerWidget {
  /// Creates a new MarcoDeck client app
  const MarcoDeckClientApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final accessibility = ref.watch(accessibilitySettingsProvider);

    // Apply the high-contrast accessibility option to the base themes when
    // enabled so the toggle in Settings actually takes effect.
    final ThemeData effectiveLight =
        accessibility.highContrastMode
            ? lightTheme.toHighContrast()
            : lightTheme;
    final ThemeData effectiveDark =
        accessibility.highContrastMode
            ? darkTheme.toHighContrast()
            : darkTheme;

    return _EagerInitialization(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MarcoDeck Client',
        theme: effectiveLight,
        darkTheme: effectiveDark,
        themeMode: themeMode,
        // Apply the user-selected text scale globally so the Text Size slider
        // in Settings affects the whole app.
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: TextScaler.linear(accessibility.textScale),
              // Propagate the reduce-motion preference (also respects the OS
              // setting if it is already enabled).
              disableAnimations:
                  accessibility.reduceAnimations || mediaQuery.disableAnimations,
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const SplashScreen(),
      ),
    );
  }
}

class _EagerInitialization extends ConsumerWidget {
  /// Creates a new eager initialization widget
  const _EagerInitialization({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(providers.serverConnectionsProvider.notifier);
    return child;
  }
}
