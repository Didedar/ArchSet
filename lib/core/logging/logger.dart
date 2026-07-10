/// Severity of a [LogRecord].
enum LogLevel { trace, debug, info, warning, error }

/// One log event, fanned out to every attached [LogObserver].
class LogRecord {
  const LogRecord(this.level, this.message, [this.error, this.stackTrace]);

  final LogLevel level;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
}

/// Receives every [LogRecord] emitted by a [Logger] it's attached to.
/// Implementations decide what to do with it (print, forward to a crash
/// reporter, etc.) — the [Logger] itself has no knowledge of sinks.
abstract class LogObserver {
  void onLog(LogRecord record);
}

/// The single funnel every error path (Flutter framework, platform, zone,
/// Bloc) routes through, per the startup error-handling map.
class Logger {
  final List<LogObserver> _observers = [];

  void addObserver(LogObserver observer) => _observers.add(observer);

  void removeObserver(LogObserver observer) => _observers.remove(observer);

  void info(String message) => _log(LogLevel.info, message);

  void warning(String message) => _log(LogLevel.warning, message);

  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _log(LogLevel.error, message, error, stackTrace);

  void _log(
    LogLevel level,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    final record = LogRecord(level, message, error, stackTrace);
    for (final observer in List<LogObserver>.of(_observers)) {
      observer.onLog(record);
    }
  }
}
