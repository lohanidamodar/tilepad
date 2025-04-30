import 'dart:async';
import 'dart:io';
import 'package:process_run/process_run.dart';

/// Service responsible for executing shell commands
class CommandExecutor {
  /// Executes a shell command and returns the result
  Future<CommandResult> executeCommand(String command) async {
    try {
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
    } catch (e) {
      return CommandResult(
        success: false,
        output: '',
        error: 'Failed to execute command: $e',
      );
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
      print('Error getting server IP: $e');
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
