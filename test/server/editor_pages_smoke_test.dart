import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tilepad/src/design/design.dart';
import 'package:tilepad/src/models/button.dart';
import 'package:tilepad/src/server/action_editor_page.dart';
import 'package:tilepad/src/server/button_editor_page.dart';
import 'package:tilepad/src/server/server.dart';

/// Smoke tests that pump the (heavily section-carded) editor pages and make
/// sure every section renders without layout exceptions.
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: buildAppTheme(
          brightness: Brightness.light,
          accent: AccentPalette.indigo,
          density: AppDensity.comfortable,
        ),
        home: child,
      );

  Button toggleButton() => Button(
        name: 'Mute',
        iconName: MacroIconsCompat.defaultId,
        actions: [ButtonAction(type: ActionType.mediaKey, key: 'mute')],
        toggleState: ToggleState(name: 'Unmute'),
        longPressActions: [
          ButtonAction(type: ActionType.delay, command: '500'),
        ],
      );

  testWidgets('button editor renders all sections for a toggle button',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(host(ButtonEditorPage(
      button: toggleButton(),
      server: TilepadServer(),
      onSave: (_) {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('Edit Button'), findsOneWidget);
    expect(find.text('Actions (1)'), findsOneWidget);
    expect(find.text('Toggle'), findsOneWidget);
    expect(find.text('Toggled-on actions (0)'), findsOneWidget);
    expect(find.text('Hold actions (1)'), findsOneWidget);
    expect(find.text('Live tile'), findsOneWidget);

    // Scroll the appearance section into view and check it laid out. The
    // page contains nested scrollables (reorderable action lists), so drag
    // the outer ListView directly instead of using scrollUntilVisible.
    await tester.drag(find.byType(ListView).first, const Offset(0, -1600));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('action editor renders each type section without errors',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester
        .pumpWidget(host(ActionEditorPage(server: TilepadServer())));
    await tester.pumpAndSettle();
    expect(find.text('Action Type'), findsOneWidget);

    // Walk through every action-type chip and make sure its section builds.
    for (final label in [
      'Preset',
      'Keystroke',
      'Open URL',
      'Media Key',
      'Navigate',
      'Delay',
      'Custom',
    ]) {
      await tester.tap(find.widgetWithText(ChoiceChip, label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'section "$label"');
    }
  });
}

/// The editor stores icons as code-point strings; reuse the app default
/// without dragging the picker into the test.
class MacroIconsCompat {
  static String get defaultId => Icons.lightbulb_outline.codePoint.toString();
}
