import 'dart:io';
import 'package:process_run/process_run.dart';
import '../utils/macos_command_handler.dart';

class CommandExecutorService {
  Future<String> executeCommand(String command) async {
    try {
      // Check if we're running on macOS
      if (Platform.isMacOS) {
        return await MacOSCommandHandler.executeCommand(command);
      }
      
      // For other platforms, use the existing implementation
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