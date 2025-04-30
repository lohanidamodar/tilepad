import 'dart:io';
import 'package:process_run/process_run.dart';

class MacOSCommandHandler {
  static Future<String> executeCommand(String command) async {
    switch (command) {
      case 'VOLUME_UP':
        return await _executeVolumeUp();
      case 'SYSTEM_INFO':
        return await _getSystemInfo();
      default:
        // For other commands, use the standard shell execution
        return await _executeShellCommand(command);
    }
  }

  static Future<String> _executeVolumeUp() async {
    try {
      // Using AppleScript for volume control
      final result = await Process.run('osascript', [
        '-e',
        'set volume output volume (output volume of (get volume settings) + 10) --max 100',
      ]);

      if (result.exitCode == 0) {
        return 'Volume increased successfully';
      } else {
        return 'Failed to increase volume: ${result.stderr}';
      }
    } catch (e) {
      return 'Error adjusting volume: $e';
    }
  }

  static Future<String> _getSystemInfo() async {
    try {
      // Get system information using sysctl
      final hostnameResult = await Process.run('hostname', []);
      final modelResult = await Process.run('sysctl', ['-n', 'hw.model']);
      final osVersionResult = await Process.run('sw_vers', ['-productVersion']);
      final memoryResult = await Process.run('sysctl', ['-n', 'hw.memsize']);

      // Convert memory from bytes to GB
      final memoryBytes =
          int.tryParse(memoryResult.stdout.toString().trim()) ?? 0;
      final memoryGB = (memoryBytes / (1024 * 1024 * 1024)).toStringAsFixed(2);

      return '''
System Information:
Hostname: ${hostnameResult.stdout.toString().trim()}
Model: ${modelResult.stdout.toString().trim()}
OS Version: ${osVersionResult.stdout.toString().trim()}
Memory: $memoryGB GB
''';
    } catch (e) {
      return 'Error retrieving system information: $e';
    }
  }

  static Future<String> _executeShellCommand(String command) async {
    try {
      var shell = Shell();
      var results = await shell.run(command);

      StringBuffer output = StringBuffer();
      for (var result in results) {
        if (result.stdout.toString().isNotEmpty) {
          output.writeln(result.stdout);
        }
        if (result.stderr.toString().isNotEmpty) {
          output.writeln(result.stderr);
        }
      }

      return output.toString().trim().isNotEmpty
          ? output.toString()
          : 'Command executed successfully with no output';
    } catch (e) {
      return 'Error executing command: $e';
    }
  }
}
