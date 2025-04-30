import 'dart:io';
import 'package:flutter/material.dart';

// Import client and server entry points
import 'src/client/main.dart' as client;
import 'src/server/main.dart' as server;

void main() {
  // Determine which app to run based on platform
  // Server runs on desktop platforms (Windows, macOS, Linux)
  // Client runs on mobile platforms (Android, iOS) and web
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    // Run server app on desktop
    server.main();
  } else {
    // Run client app on mobile and web
    client.main();
  }
}
