import 'package:flutter/foundation.dart';

/// Log level enumeration
enum LogLevel { debug, info, warning, error }

/// Enhanced logging utility for the MarcoDeck application
class MarcoDeckLogger {
  static const String _tag = 'MarcoDeck';

  /// Current log level (can be configured based on build mode)
  static LogLevel _currentLevel = kDebugMode ? LogLevel.debug : LogLevel.info;

  /// Set the current log level
  static void setLogLevel(LogLevel level) {
    _currentLevel = level;
  }

  /// Log a debug message
  static void debug(String message, [String? component]) {
    if (_currentLevel.index <= LogLevel.debug.index) {
      _log('DEBUG', message, component);
    }
  }

  /// Log an info message
  static void info(String message, [String? component]) {
    if (_currentLevel.index <= LogLevel.info.index) {
      _log('INFO', message, component);
    }
  }

  /// Log a warning message
  static void warning(String message, [String? component]) {
    if (_currentLevel.index <= LogLevel.warning.index) {
      _log('WARNING', message, component);
    }
  }

  /// Log an error message
  static void error(
    String message, [
    String? component,
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (_currentLevel.index <= LogLevel.error.index) {
      _log('ERROR', message, component);
      if (error != null) {
        debugPrint('$_tag: Error details: $error');
      }
      if (stackTrace != null && kDebugMode) {
        debugPrint('$_tag: Stack trace: $stackTrace');
      }
    }
  }

  /// Internal logging method
  static void _log(String level, String message, String? component) {
    final timestamp = DateTime.now().toIso8601String();
    final componentStr = component != null ? '[$component] ' : '';
    debugPrint('$_tag $timestamp [$level] $componentStr$message');
  }

  /// Network-specific logging
  static void network(String message, {bool isError = false}) {
    if (isError) {
      error(message, 'Network');
    } else {
      debug(message, 'Network');
    }
  }

  /// UI-specific logging
  static void ui(String message, {bool isError = false}) {
    if (isError) {
      error(message, 'UI');
    } else {
      debug(message, 'UI');
    }
  }

  /// Server-specific logging
  static void server(String message, {bool isError = false}) {
    if (isError) {
      error(message, 'Server');
    } else {
      info(message, 'Server');
    }
  }

  /// Client-specific logging
  static void client(String message, {bool isError = false}) {
    if (isError) {
      error(message, 'Client');
    } else {
      info(message, 'Client');
    }
  }
}

/// Mixin for classes that need logging capabilities
mixin LoggingMixin {
  /// Get the component name for logging
  String get logComponent => runtimeType.toString();

  /// Log a debug message
  void logDebug(String message) {
    MarcoDeckLogger.debug(message, logComponent);
  }

  /// Log an info message
  void logInfo(String message) {
    MarcoDeckLogger.info(message, logComponent);
  }

  /// Log a warning message
  void logWarning(String message) {
    MarcoDeckLogger.warning(message, logComponent);
  }

  /// Log an error message
  void logError(String message, [Object? error, StackTrace? stackTrace]) {
    MarcoDeckLogger.error(message, logComponent, error, stackTrace);
  }
}
