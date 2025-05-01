import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'server_list_screen.dart';

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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MarcoDeck Client',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4285F4)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4285F4),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const ServerListScreen(),
    );
  }
}
