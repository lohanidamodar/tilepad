// Renders the real client and editor UI headlessly and saves PNG screenshots
// to docs/screenshots/ for the README. Not part of the regular test suite —
// run manually with:
//
//   flutter test tool/screenshots/generate_screenshots_test.dart
//
// Real fonts are loaded from the Flutter SDK cache and the picons package so
// the output matches what users see (instead of the test-default Ahem boxes).
// This IS a test file, just kept outside test/ so CI doesn't run it.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Page, ConnectionState;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:marco_deck/src/client/buttons_screen.dart';
import 'package:marco_deck/src/client/client_providers.dart';
import 'package:marco_deck/src/design/design.dart';
import 'package:marco_deck/src/models/button.dart';
import 'package:marco_deck/src/models/server_connection.dart';
import 'package:marco_deck/src/server/button_editor_page.dart';
import 'package:marco_deck/src/server/button_presets.dart';
import 'package:marco_deck/src/server/server.dart';
import 'package:marco_deck/src/server/system_info.dart';

/// Connection stub: reports "connected" without touching the network.
class _FakeConnection extends ConnectionStateNotifier {
  @override
  ConnectionState build() => ConnectionState(
        status: ConnectionStatus.connected,
        connection: ServerConnection(
          name: 'Studio PC',
          address: 'ws://192.168.1.20:8080',
        ),
      );
}

Future<void> _loadFonts() async {
  Future<void> load(String family, String path) async {
    final bytes = File(path).readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }

  final flutterRoot = Platform.environment['FLUTTER_ROOT']!;
  final sdkFonts = '$flutterRoot/bin/cache/artifacts/material_fonts';
  final pubCache = Platform.environment['PUB_CACHE'] ??
      '${Platform.environment['HOME']}/.pub-cache';

  // Have the design system resolve to local families instead of google_fonts
  // (which throws asynchronously when runtime fetching is unavailable).
  AppTypography.useSystemFonts = true;
  await load('Roboto', '$sdkFonts/Roboto-Regular.ttf');

  // The multi-metric tile asks for the generic 'monospace' family.
  await load('monospace', '$sdkFonts/Roboto-Regular.ttf');
  // App-bar/system icons use Material Icons.
  await load('MaterialIcons', '$sdkFonts/MaterialIcons-Regular.otf');

  // Button icons render via MacroIcons with family PhosphorBold from picons.
  await load('packages/picons/PhosphorBold',
      '$pubCache/hosted/pub.dev/picons-3.0.1/lib/fonts/Phosphor-Bold.ttf');
}

final _shotKey = GlobalKey();

Future<void> _save(WidgetTester tester, String name) async {
  final boundary = _shotKey.currentContext!.findRenderObject()!
      as RenderRepaintBoundary;
  late final ByteData bytes;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  });
  final out = File('docs/screenshots/$name')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes.buffer.asUint8List());
  debugPrint('Wrote ${out.path} (${out.lengthSync()} bytes)');
}

Widget _host({required Widget child, required Brightness brightness}) {
  return RepaintBoundary(
    key: _shotKey,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(
        brightness: brightness,
        accent: AccentPalette.indigo,
        density: AppDensity.comfortable,
      ),
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('client deck screenshot', (tester) async {
    tester.view.physicalSize = const Size(840, 1340);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // A representative page assembled from real presets + live tiles.
    final catalog = buttonPresetCatalog();
    Button pick(String category, String name) => catalog
        .firstWhere((c) => c.name == category)
        .buttons
        .firstWhere((b) => b.name == name);
    final monitor = systemMonitorPreset();
    final window = systemPresetButtons()
        .firstWhere((b) => b.name == 'Active Window');
    final clock =
        systemPresetButtons().firstWhere((b) => b.name == 'Clock');

    final page = Page(name: 'Studio', columns: 4, tiles: [
      Tile(button: monitor, colSpan: 2, rowSpan: 2),
      Tile(button: clock, colSpan: 2),
      Tile(button: window, colSpan: 2),
      Tile(button: pick('Media', 'Previous')),
      Tile(button: pick('Media', 'Play / Pause')),
      Tile(button: pick('Media', 'Next')),
      Tile(button: pick('Media', 'Mute')),
      Tile(button: pick('Apps', 'Terminal')),
      Tile(button: pick('Apps', 'Web Browser')),
      Tile(button: pick('Meetings', 'Zoom Mute')),
      Tile(button: pick('Browser', 'New Tab')),
    ]);
    final page2 = Page(name: 'Streaming', columns: 4, order: 1);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectionStateProvider.overrideWith(_FakeConnection.new),
        ],
        child: _host(
          child: const ButtonsScreen(),
          brightness: Brightness.dark,
        ),
      ),
    );
    await tester.pump();

    // Seed pages + live values through the real providers.
    final container = ProviderScope.containerOf(
        tester.element(find.byType(ButtonsScreen)));
    container.read(pagesProvider.notifier).set([page, page2]);
    final states = container.read(pluginStatesProvider.notifier);
    states.update(systemSourceId, 'summary',
        value: 'CPU   23%\nRAM   6.4/16 GB\nDisk  41%\nUp    2d 4h');
    states.update(systemSourceId, 'clock', value: '10:24 AM');
    states.update(systemSourceId, 'window', value: 'OBS Studio — Scene 1');
    await tester.pumpAndSettle();

    await _save(tester, 'client-deck.png');
  });

  testWidgets('button editor screenshot', (tester) async {
    tester.view.physicalSize = const Size(2200, 1560);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mute = buttonPresetCatalog()
        .firstWhere((c) => c.name == 'Media')
        .buttons
        .firstWhere((b) => b.name == 'Mute');

    await tester.pumpWidget(_host(
      child: ButtonEditorPage(
        button: mute,
        server: MarcoServer(),
        onSave: (_) {},
      ),
      brightness: Brightness.light,
    ));
    await tester.pumpAndSettle();

    await _save(tester, 'button-editor.png');
  });
}
