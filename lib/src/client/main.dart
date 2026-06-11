import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'splash_screen.dart';
import 'settings_screen.dart';
import 'client_providers.dart' as providers;
import '../utils/accessibility.dart';
import '../design/design.dart';

/// Main entry point for the client app
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Start in portrait; the orientation/fullscreen settings providers re-apply
  // the user's saved preference as soon as the app boots (see
  // _EagerInitialization).
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Keep the screen awake while the app is running
  WakelockPlus.enable();

  runApp(const ProviderScope(child: TilepadClientApp()));
}

/// The Tilepad client application
class TilepadClientApp extends ConsumerWidget {
  /// Creates a new Tilepad client app
  const TilepadClientApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(personalizationProvider);
    final accessibility = ref.watch(accessibilitySettingsProvider);

    // Build the light/dark themes from design tokens for the chosen accent and
    // density, then apply the high-contrast accessibility transform if enabled.
    ThemeData themeFor(Brightness b) {
      final base = buildAppTheme(
        brightness: b,
        accent: p.accent,
        density: p.density,
      );
      return accessibility.highContrastMode ? base.toHighContrast() : base;
    }

    final effectiveLight = themeFor(Brightness.light);
    final effectiveDark = themeFor(Brightness.dark);

    return _EagerInitialization(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Tilepad Client',
        theme: effectiveLight,
        darkTheme: effectiveDark,
        themeMode: p.themeMode,
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
    // Activate display preferences early so the saved fullscreen/orientation
    // choices apply from the first frame, not the first Settings visit.
    ref.watch(providers.fullscreenProvider.notifier);
    ref.watch(providers.deckOrientationProvider.notifier);
    return child;
  }
}
