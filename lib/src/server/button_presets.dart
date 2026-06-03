import 'dart:io' show Platform;

import 'package:flutter/widgets.dart' show IconData;
import 'package:picons/picons.dart';

import '../models/button.dart';

/// A named group of ready-made [Button]s shown in the add-button picker.
///
/// These are drop-in starting points (like Touch Portal / Stream Deck's built-in
/// actions): the user picks one and it's added to their library, fully working,
/// ready to place — and editable afterwards like any button.
class PresetCategory {
  final String name;
  final List<Button> buttons;
  const PresetCategory(this.name, this.buttons);
}

/// Picks the value for the current platform.
String _byPlatform(String windows, String macos, String linux) =>
    Platform.isWindows ? windows : (Platform.isMacOS ? macos : linux);

String _icon(int codePoint) => codePoint.toString();

Button _command(String name, IconData icon, String command, String color) =>
    Button(
      name: name,
      iconName: _icon(icon.codePoint),
      color: color,
      actions: [ButtonAction(type: ActionType.command, command: command)],
    );

Button _preset(String name, IconData icon, String command, String color) =>
    Button(
      name: name,
      iconName: _icon(icon.codePoint),
      color: color,
      actions: [ButtonAction(type: ActionType.commandPreset, command: command)],
    );

Button _media(String name, IconData icon, String mediaKey, String color) =>
    Button(
      name: name,
      iconName: _icon(icon.codePoint),
      color: color,
      actions: [ButtonAction(type: ActionType.mediaKey, key: mediaKey)],
    );

Button _url(String name, IconData icon, String url, String color) => Button(
      name: name,
      iconName: _icon(icon.codePoint),
      color: color,
      actions: [ButtonAction(type: ActionType.openUrl, command: url)],
    );

Button _keys(String name, IconData icon, String key, List<String> modifiers,
        String color) =>
    Button(
      name: name,
      iconName: _icon(icon.codePoint),
      color: color,
      actions: [ButtonAction(type: ActionType.keystroke, key: key, modifiers: modifiers)],
    );

Button _nav(String name, IconData icon, String target, String color) => Button(
      name: name,
      iconName: _icon(icon.codePoint),
      color: color,
      actions: [ButtonAction(type: ActionType.navigatePage, command: target)],
    );

// Category accent colors.
const _media0 = '#7C3AED'; // violet
const _system0 = '#DC2626'; // red
const _apps0 = '#2563EB'; // blue
const _web0 = '#16A34A'; // green
const _window0 = '#0891B2'; // cyan
const _clip0 = '#0D9488'; // teal
const _nav0 = '#475569'; // slate

/// The clipboard modifier is Command on macOS, Ctrl elsewhere.
List<String> get _clipModifier => Platform.isMacOS ? const ['meta'] : const ['ctrl'];

/// All built-in preset categories, in display order.
List<PresetCategory> buttonPresetCatalog() => [
      PresetCategory('Media', [
        _media('Play / Pause', PiconsRegular.playPause, 'playPause', _media0),
        _media('Next', PiconsRegular.skipForward, 'next', _media0),
        _media('Previous', PiconsRegular.skipBack, 'previous', _media0),
        _media('Stop', PiconsRegular.stop, 'stop', _media0),
        _media('Mute', PiconsRegular.speakerX, 'mute', _media0),
        _media('Volume Up', PiconsRegular.speakerHigh, 'volumeUp', _media0),
        _media('Volume Down', PiconsRegular.speakerLow, 'volumeDown', _media0),
      ]),
      PresetCategory('System', [
        _preset(
          'Lock Screen',
          PiconsRegular.lock,
          _byPlatform('rundll32.exe user32.dll,LockWorkStation',
              'pmset displaysleepnow', 'xdg-screensaver lock'),
          _system0,
        ),
        _preset(
          'Sleep',
          PiconsRegular.moon,
          _byPlatform(
              '%windir%\\System32\\rundll32.exe powrprof.dll,SetSuspendState 0,1,0',
              'pmset sleepnow',
              'systemctl suspend'),
          _system0,
        ),
        _preset(
          'Screenshot',
          PiconsRegular.camera,
          _byPlatform(
              'powershell -command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait(\'{PRTSC}\')"',
              'screencapture -i ~/Desktop/screenshot.png',
              'gnome-screenshot -i'),
          _system0,
        ),
        _preset(
          'Restart',
          PiconsRegular.arrowsClockwise,
          _byPlatform('shutdown /r /t 0', 'sudo shutdown -r now', 'sudo reboot'),
          _system0,
        ),
        _preset(
          'Shutdown',
          PiconsRegular.power,
          _byPlatform(
              'shutdown /s /t 0', 'sudo shutdown -h now', 'sudo shutdown -h now'),
          _system0,
        ),
      ]),
      PresetCategory('Apps', [
        _command(
          'Web Browser',
          PiconsRegular.globe,
          _byPlatform('start chrome', 'open -a "Google Chrome"', 'xdg-open https://'),
          _apps0,
        ),
        _command(
          'File Manager',
          PiconsRegular.folder,
          _byPlatform('explorer', 'open ~', 'xdg-open ~'),
          _apps0,
        ),
        _command(
          'Terminal',
          PiconsRegular.terminalWindow,
          _byPlatform('start cmd', 'open -a Terminal', 'x-terminal-emulator'),
          _apps0,
        ),
        _command(
          'Calculator',
          PiconsRegular.calculator,
          _byPlatform('calc', 'open -a Calculator', 'gnome-calculator'),
          _apps0,
        ),
        _command(
          'Text Editor',
          PiconsRegular.note,
          _byPlatform('notepad', 'open -a TextEdit', 'gedit'),
          _apps0,
        ),
      ]),
      PresetCategory('Web', [
        _url('Google', PiconsRegular.magnifyingGlass, 'https://google.com', _web0),
        _url('YouTube', PiconsRegular.youtubeLogo, 'https://youtube.com', _web0),
        _url('Gmail', PiconsRegular.envelope, 'https://mail.google.com', _web0),
        _url('GitHub', PiconsRegular.githubLogo, 'https://github.com', _web0),
      ]),
      PresetCategory('Window', [
        Button(
          name: 'Select Window',
          iconName: _icon(PiconsRegular.appWindow.codePoint),
          color: _window0,
          actions: [ButtonAction(type: ActionType.selectWindow)],
        ),
        _keys('Snap Left', PiconsRegular.arrowLineLeft, 'left', const ['win'], _window0),
        _keys('Snap Right', PiconsRegular.arrowLineRight, 'right', const ['win'], _window0),
        _keys('Maximize', PiconsRegular.arrowsOut, 'up', const ['win'], _window0),
        _keys('Show Desktop', PiconsRegular.desktop, 'd', const ['win'], _window0),
      ]),
      PresetCategory('Clipboard', [
        _keys('Copy', PiconsRegular.copy, 'c', _clipModifier, _clip0),
        _keys('Paste', PiconsRegular.clipboard, 'v', _clipModifier, _clip0),
        _keys('Cut', PiconsRegular.scissors, 'x', _clipModifier, _clip0),
      ]),
      PresetCategory('Navigation', [
        _nav('Next Page', PiconsRegular.caretRight, 'next', _nav0),
        _nav('Previous Page', PiconsRegular.caretLeft, 'prev', _nav0),
      ]),
    ];

/// Flattened list of every preset button (used by tests / search).
List<Button> allPresetButtons() =>
    [for (final c in buttonPresetCatalog()) ...c.buttons];
