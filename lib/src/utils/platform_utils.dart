// This file provides platform detection utilities
// to handle differences between web and native platforms

// Use conditional imports to handle web vs. native code paths
import 'platform_utils_io.dart'
    if (dart.library.html) 'platform_utils_web.dart';

/// Returns true if running on a desktop platform (Windows, macOS, Linux)
/// This is used to determine whether to run the server or client
bool isDesktopPlatform() {
  return getPlatformType() == PlatformType.desktop;
}

/// Returns true if running on the web platform
bool isWebPlatform() {
  return getPlatformType() == PlatformType.web;
}

/// Returns true if running on a mobile platform (Android, iOS)
bool isMobilePlatform() {
  return getPlatformType() == PlatformType.mobile;
}

/// Enum representing the platform type
enum PlatformType {
  /// Desktop platforms (Windows, macOS, Linux)
  desktop,

  /// Mobile platforms (Android, iOS)
  mobile,

  /// Web platform
  web,
}
