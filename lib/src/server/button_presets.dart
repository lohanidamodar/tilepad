import 'dart:io' show Platform;

import 'package:flutter/widgets.dart' show IconData;
import 'package:picons/picons.dart';

import '../models/button.dart';
import 'plugins/plugin_manifest.dart';

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

/// A two-face toggle whose both faces press the same media key (e.g. mute /
/// unmute) — the face flip is the visual state.
Button _mediaToggle({
  required String name,
  required IconData icon,
  required String toggledName,
  required IconData toggledIcon,
  required String toggledColor,
  required String mediaKey,
  required String color,
}) =>
    Button(
      name: name,
      iconName: _icon(icon.codePoint),
      color: color,
      actions: [ButtonAction(type: ActionType.mediaKey, key: mediaKey)],
      toggleState: ToggleState(
        name: toggledName,
        iconName: _icon(toggledIcon.codePoint),
        color: toggledColor,
      ),
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
const _browser0 = '#0284C7'; // sky
const _meet0 = '#DB2777'; // pink

/// The clipboard modifier is Command on macOS, Ctrl elsewhere.
List<String> get _clipModifier => Platform.isMacOS ? const ['meta'] : const ['ctrl'];

/// All built-in preset categories, in display order.
List<PresetCategory> buttonPresetCatalog() => [
      PresetCategory('Media', [
        _media('Play / Pause', PiconsRegular.playPause, 'playPause', _media0),
        _media('Next', PiconsRegular.skipForward, 'next', _media0),
        _media('Previous', PiconsRegular.skipBack, 'previous', _media0),
        _media('Stop', PiconsRegular.stop, 'stop', _media0),
        _mediaToggle(
          name: 'Mute',
          icon: PiconsRegular.speakerX,
          toggledName: 'Unmute',
          toggledIcon: PiconsRegular.speakerSimpleX,
          toggledColor: '#DC2626',
          mediaKey: 'mute',
          color: _media0,
        ),
        _media('Volume Up', PiconsRegular.speakerHigh, 'volumeUp', _media0),
        _media('Volume Down', PiconsRegular.speakerLow, 'volumeDown', _media0),
      ]),
      PresetCategory('System', [
        _preset(
          'Lock Screen',
          PiconsRegular.lock,
          _byPlatform(
              'rundll32.exe user32.dll,LockWorkStation',
              // Ctrl+Cmd+Q is the real Lock Screen shortcut; display sleep
              // only locks when "require password after sleep" is on.
              'osascript -e \'tell application "System Events" to keystroke "q" using {control down, command down}\'',
              'xdg-screensaver lock'),
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
          // No sudo: a macro press can't answer a password prompt. macOS asks
          // System Events; Linux goes through logind/polkit.
          _byPlatform(
              'shutdown /r /t 0',
              'osascript -e \'tell app "System Events" to restart\'',
              'systemctl reboot'),
          _system0,
        ),
        _preset(
          'Shutdown',
          PiconsRegular.power,
          _byPlatform(
              'shutdown /s /t 0',
              'osascript -e \'tell app "System Events" to shut down\'',
              'systemctl poweroff'),
          _system0,
        ),
      ]),
      PresetCategory('Apps', [
        _command(
          'Web Browser',
          PiconsRegular.globe,
          _byPlatform('start chrome', 'open -a "Google Chrome"',
              'xdg-open https://www.google.com'),
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
        _command(
          'Task Manager',
          PiconsRegular.pulse,
          _byPlatform('taskmgr', 'open -a "Activity Monitor"',
              'gnome-system-monitor'),
          _apps0,
        ),
        _command(
          'Settings',
          PiconsRegular.gear,
          _byPlatform('start ms-settings:', 'open "x-apple.systempreferences:"',
              'gnome-control-center'),
          _apps0,
        ),
        _command(
          'Code Editor',
          PiconsRegular.code,
          _byPlatform('code', 'open -a "Visual Studio Code"', 'code'),
          _apps0,
        ),
        _command(
          'Spotify',
          PiconsRegular.musicNotes,
          _byPlatform('start spotify:', 'open -a Spotify', 'spotify'),
          _apps0,
        ),
        _command(
          'Downloads',
          PiconsRegular.downloadSimple,
          _byPlatform('explorer "%USERPROFILE%\\Downloads"',
              'open ~/Downloads', 'xdg-open ~/Downloads'),
          _apps0,
        ),
      ]),
      PresetCategory('Web', [
        _url('Google', PiconsRegular.magnifyingGlass, 'https://google.com', _web0),
        _url('YouTube', PiconsRegular.youtubeLogo, 'https://youtube.com', _web0),
        _url('Gmail', PiconsRegular.envelope, 'https://mail.google.com', _web0),
        _url('GitHub', PiconsRegular.githubLogo, 'https://github.com', _web0),
        _url('Twitch', PiconsRegular.twitchLogo, 'https://twitch.tv', _web0),
        _url('Reddit', PiconsRegular.redditLogo, 'https://reddit.com', _web0),
        _url('ChatGPT', PiconsRegular.chatCircleText, 'https://chatgpt.com',
            _web0),
      ]),
      // Window-management shortcuts differ per desktop: Win-key snapping on
      // Windows, Super-key (GNOME-style) on Linux, and Cmd shortcuts plus
      // Mission Control on macOS (which has no built-in snap keys to send).
      PresetCategory('Window', [
        if (Platform.isWindows)
          Button(
            name: 'Select Window',
            iconName: _icon(PiconsRegular.appWindow.codePoint),
            color: _window0,
            actions: [ButtonAction(type: ActionType.selectWindow)],
          ),
        if (Platform.isMacOS) ...[
          _command('Mission Control', PiconsRegular.squaresFour,
              'open -a "Mission Control"', _window0),
          _keys('Hide App', PiconsRegular.eyeSlash, 'h', const ['meta'],
              _window0),
          _keys('Quit App', PiconsRegular.xCircle, 'q', const ['meta'],
              _window0),
          _keys('Switch App', PiconsRegular.arrowsLeftRight, 'tab',
              const ['meta'], _window0),
          _keys('Minimize', PiconsRegular.arrowLineDown, 'm', const ['meta'],
              _window0),
        ] else ...[
          _keys('Snap Left', PiconsRegular.arrowLineLeft, 'left',
              const ['win'], _window0),
          _keys('Snap Right', PiconsRegular.arrowLineRight, 'right',
              const ['win'], _window0),
          _keys('Maximize', PiconsRegular.arrowsOut, 'up', const ['win'],
              _window0),
          _keys('Show Desktop', PiconsRegular.desktop, 'd', const ['win'],
              _window0),
          _keys('Switch App', PiconsRegular.arrowsLeftRight, 'tab',
              const ['alt'], _window0),
          _keys('Minimize', PiconsRegular.arrowLineDown,
              Platform.isWindows ? 'down' : 'h', const ['win'], _window0),
        ],
      ]),
      PresetCategory('Clipboard', [
        _keys('Copy', PiconsRegular.copy, 'c', _clipModifier, _clip0),
        _keys('Paste', PiconsRegular.clipboard, 'v', _clipModifier, _clip0),
        _keys('Cut', PiconsRegular.scissors, 'x', _clipModifier, _clip0),
        _keys('Select All', PiconsRegular.selectionAll, 'a', _clipModifier,
            _clip0),
        _keys('Undo', PiconsRegular.arrowCounterClockwise, 'z', _clipModifier,
            _clip0),
        _keys(
            'Redo',
            PiconsRegular.arrowClockwise,
            Platform.isMacOS ? 'z' : 'y',
            Platform.isMacOS ? const ['meta', 'shift'] : _clipModifier,
            _clip0),
      ]),
      // Browser tab/navigation shortcuts: same accelerators in every major
      // browser, with Cmd on macOS.
      PresetCategory('Browser', [
        _keys('New Tab', PiconsRegular.plusCircle, 't', _clipModifier,
            _browser0),
        _keys('Close Tab', PiconsRegular.xSquare, 'w', _clipModifier,
            _browser0),
        _keys(
            'Reopen Tab',
            PiconsRegular.arrowUUpLeft,
            't',
            Platform.isMacOS
                ? const ['meta', 'shift']
                : const ['ctrl', 'shift'],
            _browser0),
        _keys('Refresh', PiconsRegular.arrowsClockwise, 'r', _clipModifier,
            _browser0),
        _keys('Address Bar', PiconsRegular.textbox, 'l', _clipModifier,
            _browser0),
      ]),
      // The classic Stream Deck use case: meeting mute/camera toggles. These
      // use each app's in-app shortcut, so the meeting window must be focused
      // (combine with Select Window / Switch App, or enable the app's global
      // shortcut option where it has one).
      PresetCategory('Meetings', [
        _keys(
            'Zoom Mute',
            PiconsRegular.microphoneSlash,
            'a',
            Platform.isMacOS ? const ['meta', 'shift'] : const ['alt'],
            _meet0),
        _keys(
            'Zoom Camera',
            PiconsRegular.videoCameraSlash,
            'v',
            Platform.isMacOS ? const ['meta', 'shift'] : const ['alt'],
            _meet0),
        _keys(
            'Teams Mute',
            PiconsRegular.microphone,
            'm',
            Platform.isMacOS
                ? const ['meta', 'shift']
                : const ['ctrl', 'shift'],
            _meet0),
        _keys(
            'Teams Camera',
            PiconsRegular.videoCamera,
            'o',
            Platform.isMacOS
                ? const ['meta', 'shift']
                : const ['ctrl', 'shift'],
            _meet0),
        _keys('Meet Mute', PiconsRegular.microphoneSlash, 'd', _clipModifier,
            _meet0),
        _keys('Meet Camera', PiconsRegular.videoCameraSlash, 'e',
            _clipModifier, _meet0),
      ]),
      PresetCategory('Navigation', [
        _nav('Next Page', PiconsRegular.caretRight, 'next', _nav0),
        _nav('Previous Page', PiconsRegular.caretLeft, 'prev', _nav0),
        _nav('First Page', PiconsRegular.caretDoubleLeft, 'first', _nav0),
        _nav('Last Page', PiconsRegular.caretDoubleRight, 'last', _nav0),
      ]),
    ];

/// Flattened list of every preset button (used by tests / search).
List<Button> allPresetButtons() =>
    [for (final c in buttonPresetCatalog()) ...c.buttons];

// --- Plugin-contributed presets ------------------------------------------

/// Builds a ready-to-place [Button] from a plugin's [PluginPresetDef].
///
/// A preset bound to a state becomes a live tile; one bound to an action
/// becomes a button that invokes that plugin action.
Button pluginPresetButton(String pluginId, PluginPresetDef preset) {
  final isState = preset.stateId != null;
  final iconName = preset.icon ??
      (isState
          ? PiconsRegular.gauge.codePoint.toString()
          : PiconsRegular.broadcast.codePoint.toString());
  final color = preset.color ?? (isState ? '#334155' : '#6D28D9');
  if (isState) {
    return Button(
      name: preset.name,
      iconName: iconName,
      color: color,
      actions: const [],
      stateBinding: StateBinding(
        pluginId: pluginId,
        stateId: preset.stateId!,
        mode: StateBindingMode.title,
      ),
    );
  }
  return Button(
    name: preset.name,
    iconName: iconName,
    color: color,
    actions: [
      ButtonAction(
        type: ActionType.plugin,
        pluginId: pluginId,
        pluginActionId: preset.actionId!,
      ),
    ],
  );
}

/// The preset buttons a plugin contributes (empty if it declares none).
List<Button> pluginPresetButtons(String pluginId, List<PluginPresetDef> presets) =>
    [for (final p in presets) pluginPresetButton(pluginId, p)];
