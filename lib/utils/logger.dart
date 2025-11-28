import 'dart:developer' as developer;

/// A centralized logging system that provides consistent, pretty logging
/// throughout the application with proper error handling and stack traces.
class AppLogger {
  /// Logs an informational message
  /// 
  /// [source] - The class or module name where the log originates (e.g., 'StoryService', 'VideoPlayerWidget')
  /// [message] - The log message describing what happened
  /// [data] - Optional additional data to include in the log
  static void info(
    String source,
    String message, {
    Map<String, dynamic>? data,
  }) {
    final formattedMessage = _formatMessage('INFO', source, message, data: data);
    developer.log(
      formattedMessage,
      name: source,
    );
  }

  /// Logs a warning message
  /// 
  /// [source] - The class or module name where the log originates
  /// [message] - The log message describing the warning
  /// [data] - Optional additional data to include in the log
  static void warn(
    String source,
    String message, {
    Map<String, dynamic>? data,
  }) {
    final formattedMessage = _formatMessage('WARN', source, message, data: data);
    developer.log(
      formattedMessage,
      name: source,
      level: 900, // Warning level
    );
  }

  /// Logs an error message with optional error and stack trace
  /// 
  /// [source] - The class or module name where the log originates
  /// [message] - The log message describing the error
  /// [error] - Optional error object
  /// [stackTrace] - Optional stack trace
  /// [data] - Optional additional data to include in the log
  static void error(
    String source,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    final formattedMessage = _formatMessage('ERROR', source, message, data: data);
    
    // Always use the proper format: log("message", error: e, stackTrace: st)
    developer.log(
      formattedMessage,
      name: source,
      error: error,
      stackTrace: stackTrace,
      level: 1000, // Error level
    );
  }

  /// Formats the log message with level, source, and optional data
  static String _formatMessage(
    String level,
    String source,
    String message, {
    Map<String, dynamic>? data,
  }) {
    final buffer = StringBuffer();
    
    // Add emoji and level indicator for better visual distinction
    final emoji = _getEmojiForLevel(level);
    buffer.write('$emoji [$level] ');
    
    // Add source
    buffer.write('[$source] ');
    
    // Add message
    buffer.write(message);
    
    // Add data if provided
    if (data != null && data.isNotEmpty) {
      buffer.write(' | Data: ');
      buffer.write(data.toString());
    }
    
    return buffer.toString();
  }

  /// Returns an emoji for the log level to make logs more visually distinct
  static String _getEmojiForLevel(String level) {
    switch (level) {
      case 'INFO':
        return 'ℹ️';
      case 'WARN':
        return '⚠️';
      case 'ERROR':
        return '❌';
      default:
        return '📝';
    }
  }
}

