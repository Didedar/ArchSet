import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/core/logging/logger.dart';

class _RecordingObserver implements LogObserver {
  final records = <LogRecord>[];

  @override
  void onLog(LogRecord record) => records.add(record);
}

void main() {
  test('info() notifies observers with LogLevel.info', () {
    final logger = Logger();
    final observer = _RecordingObserver();
    logger.addObserver(observer);

    logger.info('booted');

    expect(observer.records, hasLength(1));
    expect(observer.records.single.level, LogLevel.info);
    expect(observer.records.single.message, 'booted');
  });

  test('error() carries the error object and stack trace to observers', () {
    final logger = Logger();
    final observer = _RecordingObserver();
    logger.addObserver(observer);
    final stackTrace = StackTrace.current;

    logger.error('boom', Exception('bad'), stackTrace);

    final record = observer.records.single;
    expect(record.level, LogLevel.error);
    expect(record.message, 'boom');
    expect(record.error, isException);
    expect(record.stackTrace, stackTrace);
  });

  test('a log before any observer is attached does not throw', () {
    expect(() => Logger().info('no observers yet'), returnsNormally);
  });

  test('removing an observer stops it from receiving further logs', () {
    final logger = Logger();
    final observer = _RecordingObserver();
    logger.addObserver(observer);
    logger.removeObserver(observer);

    logger.info('after removal');

    expect(observer.records, isEmpty);
  });
}
