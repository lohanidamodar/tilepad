import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:marco_deck/src/models/button.dart';
import 'package:marco_deck/src/server/button_presets.dart';
import 'package:marco_deck/src/server/system_info.dart';

/// Sanity checks that the preset catalog built for the CURRENT platform only
/// contains commands that can actually work here (CI runs these on Linux and
/// the analyzer keeps the other platform branches compiling).
void main() {
  Iterable<ButtonAction> allActions() sync* {
    for (final button in allPresetButtons()) {
      yield* button.actions;
      yield* button.longPressActions;
      if (button.toggleState != null) yield* button.toggleState!.actions;
    }
  }

  test('no preset shells out to sudo (a press cannot answer a prompt)', () {
    for (final action in allActions()) {
      expect(action.command.contains('sudo '), isFalse,
          reason: '"${action.command}" requires a password prompt');
    }
  });

  test('selectWindow preset only exists on Windows (no-op elsewhere)', () {
    final hasSelectWindow =
        allActions().any((a) => a.type == ActionType.selectWindow);
    expect(hasSelectWindow, Platform.isWindows);
  });

  test('openUrl presets carry a complete URL', () {
    for (final action in allActions()) {
      if (action.type != ActionType.openUrl) continue;
      expect(Uri.parse(action.command).host, isNotEmpty,
          reason: '"${action.command}" is not a complete URL');
    }
  });

  test('media-key presets use only keys every platform executor accepts', () {
    const supported = {
      'playPause', 'next', 'previous', 'stop', 'mute', 'volumeUp', 'volumeDown'
    };
    for (final action in allActions()) {
      if (action.type != ActionType.mediaKey) continue;
      expect(supported.contains(action.key), isTrue,
          reason: '"${action.key}" is not a supported media key');
    }
  });

  test('the Active Window live tile is offered as a system preset', () {
    final presets = systemPresetButtons();
    final tile = presets.firstWhere((b) => b.name == 'Active Window');
    expect(tile.stateBinding?.stateId, 'window');
    expect(tile.actions, isEmpty);
  });

  test('the Mute toggle preset exposes a second face', () {
    final mute = allPresetButtons().firstWhere((b) => b.name == 'Mute');
    expect(mute.toggleState, isNotNull);
    expect(mute.toggleState!.name, 'Unmute');
  });
}
