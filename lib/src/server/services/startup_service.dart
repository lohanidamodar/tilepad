import 'dart:io';

import 'package:flutter/foundation.dart';

/// Manages the OS "launch at login" entry for the server executable.
///
/// The OS entry itself is the source of truth — nothing is stored in
/// preferences, so the toggle always reflects what the OS will actually do:
///  - Windows: a value under `HKCU\...\CurrentVersion\Run` (written with the
///    `reg` tool; per-user, no elevation needed),
///  - macOS: a LaunchAgent plist in `~/Library/LaunchAgents`,
///  - Linux: an XDG autostart `.desktop` entry in `~/.config/autostart`.
///
/// Enabling rewrites the entry with the current executable path, so a moved
/// installation heals itself the next time the toggle is switched on.
class StartupService {
  static const _windowsRunKey =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _windowsValueName = 'Tilepad';
  static const _macosLabel = 'dev.appwriters.tilepad';

  final String _os;
  final String _executable;
  final Map<String, String> _environment;
  final Future<ProcessResult> Function(String, List<String>) _run;

  /// The parameters exist for tests; production code uses the defaults.
  StartupService({
    String? operatingSystem,
    String? executable,
    Map<String, String>? environment,
    Future<ProcessResult> Function(String, List<String>)? runProcess,
  })  : _os = operatingSystem ?? Platform.operatingSystem,
        _executable = executable ?? Platform.resolvedExecutable,
        _environment = environment ?? Platform.environment,
        _run = runProcess ?? Process.run;

  /// Launch-at-login is a desktop-OS concept; the toggle is hidden elsewhere.
  static bool get isSupported =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Whether the OS currently has a launch-at-login entry for Tilepad.
  Future<bool> isEnabled() async {
    try {
      switch (_os) {
        case 'windows':
          final out = await _run(
              'reg', ['query', _windowsRunKey, '/v', _windowsValueName]);
          return out.exitCode == 0;
        case 'macos':
          return _macosPlistFile().existsSync();
        case 'linux':
          return _linuxDesktopFile().existsSync();
      }
    } catch (e) {
      debugPrint('StartupService isEnabled error: $e');
    }
    return false;
  }

  /// Adds or removes the launch-at-login entry. Returns whether the change
  /// was applied; on failure the OS entry is left as it was.
  Future<bool> setEnabled(bool value) async {
    try {
      switch (_os) {
        case 'windows':
          return _setWindows(value);
        case 'macos':
          return _setFile(_macosPlistFile(), value ? _macosPlist() : null);
        case 'linux':
          return _setFile(
              _linuxDesktopFile(), value ? _linuxDesktopEntry() : null);
      }
    } catch (e) {
      debugPrint('StartupService setEnabled error: $e');
    }
    return false;
  }

  Future<bool> _setWindows(bool value) async {
    // The value data is the quoted executable path, as Run entries expect.
    final out = await _run(
      'reg',
      value
          ? [
              'add', _windowsRunKey,
              '/v', _windowsValueName,
              '/t', 'REG_SZ',
              '/d', '"$_executable"',
              '/f',
            ]
          : ['delete', _windowsRunKey, '/v', _windowsValueName, '/f'],
    );
    if (out.exitCode == 0) return true;
    // Deleting an entry that doesn't exist is already the desired state.
    return !value && !await isEnabled();
  }

  bool _setFile(File file, String? contents) {
    if (contents == null) {
      if (file.existsSync()) file.deleteSync();
      return true;
    }
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
    return true;
  }

  @visibleForTesting
  File linuxDesktopFile() => _linuxDesktopFile();

  File _linuxDesktopFile() {
    final config = _environment['XDG_CONFIG_HOME'] ??
        '${_environment['HOME']}/.config';
    return File('$config/autostart/tilepad.desktop');
  }

  @visibleForTesting
  String linuxDesktopEntry() => _linuxDesktopEntry();

  String _linuxDesktopEntry() => '''
[Desktop Entry]
Type=Application
Name=Tilepad
Comment=Start the Tilepad server at login
Exec="$_executable"
Terminal=false
X-GNOME-Autostart-enabled=true
''';

  @visibleForTesting
  File macosPlistFile() => _macosPlistFile();

  File _macosPlistFile() =>
      File('${_environment['HOME']}/Library/LaunchAgents/$_macosLabel.plist');

  @visibleForTesting
  String macosPlist() => _macosPlist();

  String _macosPlist() {
    final exe = _executable
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    return '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$_macosLabel</string>
  <key>ProgramArguments</key>
  <array>
    <string>$exe</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
''';
  }
}
