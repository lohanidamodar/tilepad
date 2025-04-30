import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:process_run/process_run.dart';

import '../utils/win32_keyboard.dart';

/// Service responsible for executing shell commands and keystrokes
class CommandExecutor {
  /// Executes a shell command and returns the result
  Future<CommandResult> executeCommand(String command) async {
    try {
      if (Platform.isWindows) {
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

        return executeCommand(command);
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

      // Filter out loopback interfaces and get IPv4 addresses
      for (var interface in interfaces) {
        // Skip loopback interfaces
        if (interface.name.contains('loopback') ||
            interface.name.contains('lo')) {
          continue;
        }

        // Get IPv4 address
        final ipv4Address =
            interface.addresses
                .where((addr) => addr.type == InternetAddressType.IPv4)
                .map((addr) => addr.address)
                .firstOrNull;

        if (ipv4Address != null) {
          return ipv4Address;
        }
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
