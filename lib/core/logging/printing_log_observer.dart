import 'logger.dart';

/// Prints every [LogRecord] to the console. Attached in non-release builds
/// only — [AppRunner] decides when to add it.
class PrintingLogObserver implements LogObserver {
  const PrintingLogObserver();

  @override
  void onLog(LogRecord record) {
    final buffer = StringBuffer('[${record.level.name}] ${record.message}');
    if (record.error != null) buffer.write(' — ${record.error}');
    if (record.stackTrace != null) buffer.write('\n${record.stackTrace}');
    // ignore: avoid_print
    print(buffer.toString());
  }
}
