import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:process_run/process_run.dart';

import '../models/button.dart';
import '../models/window_info.dart';
import '../utils/win32_keyboard.dart';
import '../utils/win32_commands.dart';
import '../utils/win32_windows.dart';
import 'plugins/plugin_host.dart';

/// Invokes a plugin action and returns its result. Wired by the server to
/// [PluginHost.invoke]; left null in contexts without a plugin host.
typedef PluginActionInvoker = Future<PluginActionResult> Function(
  String pluginId,
  String actionId,
  Map<String, dynamic> settings,
);

/// Service responsible for executing shell commands and keystrokes
class CommandExecutor {
  /// Optional bridge to the plugin host for [ActionType.plugin] actions.
  PluginActionInvoker? pluginInvoker;

  /// Executes a button with all of its actions in sequence. Toggle buttons
  /// run the actions of their currently active face.
  Future<CommandResult> execute(Button button) =>
      executeActions(button.effectiveActions);

  /// Executes a list of actions in sequence and combines their results.
  Future<CommandResult> executeActions(List<ButtonAction> actions) async {
    // If there are no actions, return an error
    if (actions.isEmpty) {
      return CommandResult(
        success: false,
        output: '',
        error: 'Button has no actions to execute',
      );
    }

    // For a single action, use simple execution
    if (actions.length == 1) {
      return await executeAction(actions.first);
    }

    // For multiple actions, execute them in sequence and combine results
    final results = <CommandResult>[];
    for (final action in actions) {
      final result = await executeAction(action);
      results.add(result);

      // Add a small delay between actions to ensure they complete in order
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Combine results from all actions
    final success = results.every((result) => result.success);
    final output = results
        .map((r) => r.output)
        .where((o) => o.isNotEmpty)
        .join('\n');
    final error = results
        .map((r) => r.error)
        .where((e) => e.isNotEmpty)
        .join('\n');

    return CommandResult(success: success, output: output, error: error);
  }

  /// Executes a single button action based on its type
  Future<CommandResult> executeAction(ButtonAction action) async {
    switch (action.type) {
      case ActionType.command:
      case ActionType.commandPreset:
        return await executeCommand(action.command);

      case ActionType.keystroke:
        return await executeKeystroke(action.key, action.modifiers);

      case ActionType.promptText:
        // Without a client-supplied value, fall back to any stored default.
        return await executeTypeText(action.command);

      case ActionType.promptKeystroke:
        return await executeKeystroke(action.key, action.modifiers);

      case ActionType.selectWindow:
        // Activation needs a window chosen on the client; nothing to do here.
        return CommandResult(
          success: true,
          output: 'Pick a window on the device',
          error: '',
        );

      case ActionType.openUrl:
        return await executeOpenUrl(action.command);

      case ActionType.mediaKey:
        return await executeMediaKey(action.key);

      case ActionType.navigatePage:
        // Page navigation happens on the client; the server has nothing to do.
        return CommandResult(
          success: true,
          output: 'Handled on the device',
          error: '',
        );

      case ActionType.plugin:
        return await executePluginAction(action);

      case ActionType.delay:
        return await executeDelay(action.command);
    }
  }

  /// Waits for the given number of milliseconds (stored as the action's
  /// command). Used to pace multi-action sequences; capped at 60 seconds so a
  /// typo can't hang the press pipeline.
  Future<CommandResult> executeDelay(String milliseconds) async {
    final ms = int.tryParse(milliseconds.trim());
    if (ms == null || ms < 0) {
      return CommandResult(
        success: false,
        output: '',
        error: 'Invalid delay: "$milliseconds" is not a number of milliseconds',
      );
    }
    final clamped = ms.clamp(0, 60000);
    await Future.delayed(Duration(milliseconds: clamped));
    return CommandResult(success: true, output: '', error: '');
  }

  /// Opens a URL (or file/folder path) with the OS default handler.
  Future<CommandResult> executeOpenUrl(String target) async {
    final url = target.trim();
    if (url.isEmpty) {
      return CommandResult(
        success: false,
        output: '',
        error: 'No URL to open',
      );
    }
    try {
      late final ProcessResult result;
      if (Platform.isWindows) {
        // `start` is a cmd builtin; the empty "" is the window title argument so
        // a quoted URL isn't mistaken for it.
        result = await Process.run('cmd.exe', ['/c', 'start', '', url]);
      } else if (Platform.isMacOS) {
        result = await Process.run('open', [url]);
      } else {
        result = await Process.run('xdg-open', [url]);
      }
      final ok = result.exitCode == 0;
      return CommandResult(
        success: ok,
        output: ok ? 'Opened $url' : '',
        error: ok ? '' : (result.stderr.toString().trim()),
      );
    } catch (e) {
      return CommandResult(
        success: false,
        output: '',
        error: 'Failed to open URL: $e',
      );
    }
  }

  /// Presses a media transport / volume key. [name] is one of: playPause,
  /// next, previous, stop, mute, volumeUp, volumeDown.
  Future<CommandResult> executeMediaKey(String name) async {
    final key = name.trim();
    if (key.isEmpty) {
      return CommandResult(success: false, output: '', error: 'No media key');
    }
    try {
      if (Platform.isWindows) {
        // Win32 has dedicated virtual keys for media/volume; route through the
        // keyboard helper which maps the media* key names to those VKs.
        final ok = Win32Keyboard.sendKeystroke('media_$key', const []);
        return CommandResult(
          success: ok,
          output: ok ? 'Media key: $key' : '',
          error: ok ? '' : 'Failed to send media key',
        );
      } else if (Platform.isMacOS) {
        final command = _macMediaKeyCommand(key);
        if (command == null) {
          return CommandResult(
            success: false,
            output: '',
            error: 'Unsupported media key: $key',
          );
        }
        return await executeCommand(command);
      } else {
        final command = _linuxMediaKeyCommand(key);
        if (command == null) {
          return CommandResult(
            success: false,
            output: '',
            error: 'Unsupported media key: $key',
          );
        }
        return await executeCommand(command);
      }
    } catch (e) {
      return CommandResult(
        success: false,
        output: '',
        error: 'Failed to send media key: $e',
      );
    }
  }

  /// macOS media-key command. Volume uses AppleScript volume settings;
  /// transport drives Music and Spotify directly — synthesising F7–F9 key
  /// codes does NOT trigger the hardware media functions, so scripting the
  /// players is the reliable route.
  static String? _macMediaKeyCommand(String key) {
    // Sends [verb] to whichever supported player is running.
    String players(String verb) =>
        'osascript -e \'if application "Spotify" is running then tell application "Spotify" to $verb\' '
        '-e \'if application "Music" is running then tell application "Music" to $verb\'';
    switch (key) {
      case 'playPause':
        return players('playpause');
      case 'next':
        return players('next track');
      case 'previous':
        return players('previous track');
      case 'stop':
        return players('pause');
      case 'mute':
        return 'osascript -e \'set volume output muted (not (output muted of (get volume settings)))\'';
      case 'volumeUp':
        return 'osascript -e \'set volume output volume ((output volume of (get volume settings)) + 6)\'';
      case 'volumeDown':
        return 'osascript -e \'set volume output volume ((output volume of (get volume settings)) - 6)\'';
      default:
        return null;
    }
  }

  /// Linux media-key command. Transport keys use `playerctl`; volume uses
  /// `pactl` on the default sink.
  static String? _linuxMediaKeyCommand(String key) {
    switch (key) {
      case 'playPause':
        return 'playerctl play-pause';
      case 'next':
        return 'playerctl next';
      case 'previous':
        return 'playerctl previous';
      case 'stop':
        return 'playerctl stop';
      case 'mute':
        return 'pactl set-sink-mute @DEFAULT_SINK@ toggle';
      case 'volumeUp':
        return 'pactl set-sink-volume @DEFAULT_SINK@ +6%';
      case 'volumeDown':
        return 'pactl set-sink-volume @DEFAULT_SINK@ -6%';
      default:
        return null;
    }
  }

  /// Routes a plugin action to the plugin host via [pluginInvoker].
  Future<CommandResult> executePluginAction(ButtonAction action) async {
    final invoker = pluginInvoker;
    if (invoker == null) {
      return CommandResult(
        success: false,
        output: '',
        error: 'No plugin host available to run this plugin action',
      );
    }
    final result =
        await invoker(action.pluginId, action.pluginActionId, action.settings);
    return CommandResult(
      success: result.success,
      output: result.output,
      error: result.error,
    );
  }

  /// Legacy method for backward compatibility
  Future<CommandResult> executeLegacy(Button button) async {
    switch (button.type) {
      case ButtonType.command:
      case ButtonType.commandPreset:
        return await executeCommand(button.command);

      case ButtonType.keystroke:
      case ButtonType.promptKeystroke:
        return await executeKeystroke(button.key, button.modifiers);

      case ButtonType.promptText:
        return await executeTypeText(button.command);

      case ButtonType.selectWindow:
        return CommandResult(
          success: true,
          output: 'Pick a window on the device',
          error: '',
        );

      case ButtonType.plugin:
        // Plugin actions use the new multi-action path; route via the first
        // action so legacy single-action callers still work.
        if (button.actions.isEmpty) {
          return CommandResult(
            success: false,
            output: '',
            error: 'Plugin button has no action to run',
          );
        }
        return await executePluginAction(button.actions.first);
    }
  }

  /// Lists the server's open windows (Windows only; empty elsewhere).
  List<WindowInfo> listWindows() {
    if (Platform.isWindows) return Win32Windows.list();
    return const [];
  }

  /// Brings the window with the given [handle] to the foreground.
  Future<CommandResult> activateWindow(String handle) async {
    if (Platform.isWindows) {
      final ok = Win32Windows.activate(handle);
      return CommandResult(
        success: ok,
        output: ok ? 'Activated window' : '',
        error: ok ? '' : 'Failed to activate window',
      );
    }
    return CommandResult(
      success: false,
      output: '',
      error: 'Window activation is not supported on this platform',
    );
  }

  /// Types arbitrary [text] into the currently focused window.
  ///
  /// Used by dynamic "Prompt for Text" buttons, where the text is supplied by
  /// the client at press time.
  Future<CommandResult> executeTypeText(String text) async {
    if (text.isEmpty) {
      return CommandResult(success: true, output: '', error: '');
    }
    try {
      if (Platform.isWindows) {
        final ok = Win32Keyboard.typeText(text);
        return CommandResult(
          success: ok,
          output: ok ? 'Typed "$text"' : '',
          error: ok ? '' : 'Failed to type text',
        );
      } else if (Platform.isMacOS) {
        final escaped = text.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
        return await executeCommand(
          'osascript -e \'tell application "System Events" to keystroke "$escaped"\'',
        );
      } else if (Platform.isLinux) {
        final escaped = text.replaceAll("'", "'\\''");
        return await executeCommand("xdotool type --clearmodifiers -- '$escaped'");
      }
      return CommandResult(
        success: false,
        output: '',
        error: 'Typing text is not supported on this platform',
      );
    } catch (e) {
      return CommandResult(
        success: false,
        output: '',
        error: 'Error typing text: $e',
      );
    }
  }

  /// Executes a shell command and returns the result
  Future<CommandResult> executeCommand(String command) async {
    try {
      // Check for special Win32 command patterns
      if (Platform.isWindows) {
        // Sleep command
        if (command.contains(
          '%windir%\\System32\\rundll32.exe powrprof.dll,SetSuspendState',
        )) {
          return await executeWin32Sleep();
        }
        // Shutdown command
        else if (command.contains('shutdown /s /t 0')) {
          return await executeWin32Shutdown();
        }
        // Restart command
        else if (command.contains('shutdown /r /t 0')) {
          return await executeWin32Restart();
        }
        // Lock screen command
        else if (command.contains('rundll32.exe user32.dll,LockWorkStation')) {
          return await executeWin32LockWorkstation();
        }
        // Screenshot command
        else if (command.contains('powershell') &&
            command.contains('SendKeys]::SendWait') &&
            command.contains('PRTSC')) {
          return await executeWin32Screenshot();
        }
        // Volume commands
        else if (command.contains('powershell') &&
            command.contains('wscript.shell') &&
            command.contains('[char]175')) {
          return await executeWin32VolumeAction('up');
        } else if (command.contains('powershell') &&
            command.contains('wscript.shell') &&
            command.contains('[char]174')) {
          return await executeWin32VolumeAction('down');
        } else if (command.contains('powershell') &&
            command.contains('wscript.shell') &&
            command.contains('[char]173')) {
          return await executeWin32VolumeAction('mute');
        }

        // Special handling for Windows
        return await _executeWindowsCommand(command);
      } else {
        // Regular execution for other platforms
        final shell = Shell();
        final result = await shell.run(command);

        final stdout = result
            .map((process) => process.stdout.toString())
            .join('\n');
        final stderr = result
            .map((process) => process.stderr.toString())
            .join('\n');

        return CommandResult(
          success: stderr.isEmpty,
          output: stdout,
          error: stderr,
        );
      }
    } catch (e) {
      debugPrint('Command execution error: $e');
      return CommandResult(
        success: false,
        output: '',
        error: 'Failed to execute command: $e',
      );
    }
  }

  /// Execute Sleep command using Win32 API
  Future<CommandResult> executeWin32Sleep() async {
    final success = Win32Commands.sleep();
    return CommandResult(
      success: success,
      output: success ? 'Computer put to sleep mode' : '',
      error: success ? '' : 'Failed to put computer to sleep',
    );
  }

  /// Execute Shutdown command using Win32 API
  Future<CommandResult> executeWin32Shutdown() async {
    final success = Win32Commands.shutdown();
    return CommandResult(
      success: success,
      output: success ? 'Computer shutting down' : '',
      error: success ? '' : 'Failed to shut down computer',
    );
  }

  /// Execute Restart command using Win32 API
  Future<CommandResult> executeWin32Restart() async {
    final success = Win32Commands.restart();
    return CommandResult(
      success: success,
      output: success ? 'Computer restarting' : '',
      error: success ? '' : 'Failed to restart computer',
    );
  }

  /// Execute Lock Workstation command using Win32 API
  Future<CommandResult> executeWin32LockWorkstation() async {
    final success = Win32Commands.lockWorkstation();
    return CommandResult(
      success: success,
      output: success ? 'Workstation locked' : '',
      error: success ? '' : 'Failed to lock workstation',
    );
  }

  /// Execute Screenshot command using Win32 API
  Future<CommandResult> executeWin32Screenshot() async {
    final success = await Win32Commands.takeScreenshot();
    return CommandResult(
      success: success,
      output: success ? 'Screenshot taken and saved to Desktop' : '',
      error: success ? '' : 'Failed to take screenshot',
    );
  }

  /// Execute Volume actions using Win32 API
  Future<CommandResult> executeWin32VolumeAction(String action) async {
    final success = Win32Commands.adjustVolume(action);
    String actionText =
        action == 'up'
            ? 'increased'
            : action == 'down'
            ? 'decreased'
            : 'toggled';

    return CommandResult(
      success: success,
      output: success ? 'Volume $actionText' : '',
      error: success ? '' : 'Failed to change volume',
    );
  }

  /// Special handling for Windows command execution
  Future<CommandResult> _executeWindowsCommand(String command) async {
    try {
      // Use cmd.exe to run the command
      final process = await Process.run(
        'cmd.exe',
        ['/c', command],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      return CommandResult(
        success: process.exitCode == 0,
        output: process.stdout,
        error: process.stderr,
      );
    } catch (e) {
      debugPrint('Windows command execution error: $e');
      return CommandResult(
        success: false,
        output: '',
        error: 'Windows command execution failed: $e',
      );
    }
  }

  /// Simulates keystroke(s) and returns the result
  Future<CommandResult> executeKeystroke(
    String key,
    List<String> modifiers,
  ) async {
    try {
      if (Platform.isWindows) {
        // Use direct Win32 API for Windows
        return await _executeWindowsKeystrokeNative(key, modifiers);
      } else {
        String command;

        if (Platform.isMacOS) {
          command = _createMacOSKeystrokeCommand(key, modifiers);
        } else if (Platform.isLinux) {
          command = _createLinuxKeystrokeCommand(key, modifiers);
        } else {
          return CommandResult(
            success: false,
            output: '',
            error: 'Keystroke simulation not supported on this platform',
          );
        }

        return await executeCommand(command);
      }
    } catch (e) {
      debugPrint('Keystroke execution error: $e');
      return CommandResult(
        success: false,
        output: '',
        error: 'Failed to execute keystroke: $e',
      );
    }
  }

  /// Uses the Win32 API directly to simulate keystrokes
  Future<CommandResult> _executeWindowsKeystrokeNative(
    String key,
    List<String> modifiers,
  ) async {
    try {
      // Call our Win32 keyboard implementation
      final success = Win32Keyboard.sendKeystroke(key, modifiers);

      if (success) {
        return CommandResult(
          success: true,
          output:
              'Keystroke sent: ${_getReadableKeystrokeDescription(key, modifiers)}',
          error: '',
        );
      } else {
        return CommandResult(
          success: false,
          output: '',
          error: 'Failed to send keystroke',
        );
      }
    } catch (e) {
      debugPrint('Win32 keystroke error: $e');
      return CommandResult(
        success: false,
        output: '',
        error: 'Win32 keystroke execution failed: $e',
      );
    }
  }

  /// Gets a human-readable description of the keystroke
  String _getReadableKeystrokeDescription(String key, List<String> modifiers) {
    final modifierNames = modifiers.map((m) => m.toUpperCase()).join('+');
    final keyName = key.toUpperCase();

    return modifierNames.isNotEmpty ? '$modifierNames+$keyName' : keyName;
  }

  /// Creates a command for simulating keystrokes on macOS using AppleScript
  String _createMacOSKeystrokeCommand(String key, List<String> modifiers) {
    // Map of modifier keys to their AppleScript syntax
    final modifierMap = {
      'ctrl': 'control',
      'shift': 'shift',
      'alt': 'option',
      'meta': 'command',
      'win': 'command',
    };

    // Build AppleScript command
    final modifierList =
        modifiers
            .where((m) => modifierMap.containsKey(m.toLowerCase()))
            .map((m) => modifierMap[m.toLowerCase()]!)
            .toList();

    String modifierString =
        modifierList.isEmpty ? '' : '{${modifierList.join(", ")}} ';

    // Special keys in AppleScript
    final keyMap = {
      'enter': 'return',
      'tab': 'tab',
      'esc': 'escape',
      'escape': 'escape',
      'space': 'space',
      'backspace': 'delete',
      'delete': 'forward delete',
      'home': 'home',
      'end': 'end',
      'pageup': 'page up',
      'pagedown': 'page down',
      'up': 'up arrow',
      'down': 'down arrow',
      'left': 'left arrow',
      'right': 'right arrow',
    };

    final keyLower = key.toLowerCase();
    String keyString;

    if (keyMap.containsKey(keyLower)) {
      keyString = keyMap[keyLower]!;
    } else if (key.toLowerCase().startsWith('f') && key.length > 1) {
      // Function keys F1-F20
      keyString = key.toLowerCase();
    } else {
      // Single character keys
      keyString = key.toLowerCase();
    }

    // Build AppleScript to send keystrokes
    final script = '''
      tell application "System Events"
        keystroke "$keyString" ${modifierString.isNotEmpty ? "using $modifierString" : ""}
      end tell
    ''';

    return "osascript -e '$script'";
  }

  /// Creates a command for simulating keystrokes on Linux using xdotool
  String _createLinuxKeystrokeCommand(String key, List<String> modifiers) {
    // Map of modifier keys to their xdotool syntax
    final modifierMap = {
      'ctrl': 'ctrl',
      'shift': 'shift',
      'alt': 'alt',
      'meta': 'super',
      'win': 'super',
    };

    // Convert modifiers to xdotool format
    final modifierList =
        modifiers
            .where((m) => modifierMap.containsKey(m.toLowerCase()))
            .map((m) => modifierMap[m.toLowerCase()]!)
            .toList();

    // Special keys in xdotool
    final keyMap = {
      'enter': 'Return',
      'tab': 'Tab',
      'esc': 'Escape',
      'escape': 'Escape',
      'space': 'space',
      'backspace': 'BackSpace',
      'delete': 'Delete',
      'home': 'Home',
      'end': 'End',
      'pageup': 'Page_Up',
      'pagedown': 'Page_Down',
      'up': 'Up',
      'down': 'Down',
      'left': 'Left',
      'right': 'Right',
    };

    final keyLower = key.toLowerCase();
    String keyString;

    if (keyMap.containsKey(keyLower)) {
      keyString = keyMap[keyLower]!;
    } else if (key.toLowerCase().startsWith('f') && key.length > 1) {
      // Function keys F1-F12
      keyString = key.toUpperCase();
    } else {
      // Single character keys
      keyString = key.toLowerCase();
    }

    if (modifierList.isEmpty) {
      return 'xdotool key $keyString';
    } else {
      return 'xdotool key ${modifierList.join("+")}+$keyString';
    }
  }

  /// Gets the server's IP address that can be used by clients to connect
  Future<String> getServerIpAddress() async {
    try {
      // Get all network interfaces
      final interfaces = await NetworkInterface.list();

      String? fallbackIp;

      // Filter out loopback interfaces and get IPv4 addresses
      for (var interface in interfaces) {
        // Skip loopback interfaces
        if (interface.name.toLowerCase().contains('loopback') ||
            interface.name.toLowerCase() == 'lo') {
          continue;
        }

        // Get IPv4 addresses for this interface
        final ipv4Addresses =
            interface.addresses
                .where((addr) => addr.type == InternetAddressType.IPv4)
                .map((addr) => addr.address)
                .toList();

        if (ipv4Addresses.isEmpty) continue;

        final ipAddress = ipv4Addresses.first;
        final nameLower = interface.name.toLowerCase();

        // Prefer Wi-Fi and Ethernet interfaces
        if (nameLower.contains('wi-fi') ||
            nameLower.contains('wifi') ||
            nameLower.contains('wlan') ||
            nameLower.contains('eth') ||
            nameLower.contains('en0') ||
            nameLower.contains('en1')) {
          debugPrint(
            'Found active network interface: ${interface.name} -> $ipAddress',
          );
          return ipAddress;
        }

        // Keep first valid IP as fallback
        fallbackIp ??= ipAddress;
      }

      if (fallbackIp != null) {
        debugPrint('Using fallback IP address: $fallbackIp');
        return fallbackIp;
      }

      return 'localhost';
    } catch (e) {
      debugPrint('Error getting server IP: $e');
      return 'localhost';
    }
  }
}

/// Result of executing a command
class CommandResult {
  /// Whether the command was successful
  final bool success;

  /// Standard output of the command
  final String output;

  /// Standard error of the command
  final String error;

  /// Creates a new command result
  CommandResult({
    required this.success,
    required this.output,
    required this.error,
  });

  /// Converts to a JSON map
  Map<String, dynamic> toJson() {
    return {'success': success, 'output': output, 'error': error};
  }
}
