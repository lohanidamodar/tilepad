import 'dart:io';
import 'platform_utils.dart';

/// Gets the platform type for IO platforms
PlatformType getPlatformType() {
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    return PlatformType.desktop;
  } else if (Platform.isAndroid || Platform.isIOS) {
    return PlatformType.mobile;
  }
  
  // Default fallback - should not reach here
  return PlatformType.mobile;
}