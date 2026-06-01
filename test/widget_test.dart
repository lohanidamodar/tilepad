// Basic Flutter widget test for the MarcoDeck client app.
//
// The client app is a Riverpod app whose first screen (the splash screen)
// drives animations, persisted-preference loads, and a navigation transition.
// The test therefore:
//   * provides a mock SharedPreferences store so the providers can initialise,
//   * wraps the app in a ProviderScope (required for ConsumerWidgets), and
//   * settles all scheduled timers/animations before asserting.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:marco_deck/src/client/main.dart';

void main() {
  testWidgets('App boots and renders a MaterialApp', (
    WidgetTester tester,
  ) async {
    // The client is portrait-locked, so use a representative portrait phone
    // surface rather than the default 800x600 (which is landscape-ish and
    // causes the connection screens to overflow vertically).
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Provide an empty persisted store so preference loads resolve cleanly.
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(child: MarcoDeckClientApp()),
    );

    // Verify the app shell is present immediately.
    expect(find.byType(MaterialApp), findsOneWidget);

    // Drain the splash-screen animations, preference loads, and the
    // navigation transition so the test does not leave pending timers.
    await tester.pumpAndSettle();

    // The app should still be mounted after initialisation completes.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
