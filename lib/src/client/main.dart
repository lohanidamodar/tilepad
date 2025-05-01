import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'splash_screen.dart';
import 'client_providers.dart' as providers;

/// Main entry point for the client app
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait orientation for the client app
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: MarcoDeckClientApp()));
}

/// The MarcoDeck client application
class MarcoDeckClientApp extends ConsumerWidget {
  /// Creates a new MarcoDeck client app
  const MarcoDeckClientApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _EagerInitialization(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MarcoDeck Client',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4285F4)),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(centerTitle: true, elevation: 2),
        ),
        darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4285F4),
            brightness: Brightness.dark,
          ),
          appBarTheme: const AppBarTheme(centerTitle: true, elevation: 2),
        ),
        themeMode: ThemeMode.system,
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
