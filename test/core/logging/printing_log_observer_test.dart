import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/core/logging/logger.dart';
import 'package:archset_r2/core/logging/printing_log_observer.dart';

void main() {
  test('prints the level and message for every record', () {
    final printed = <String>[];

    runZoned(
      () => const PrintingLogObserver()
          .onLog(const LogRecord(LogLevel.info, 'booted')),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => printed.add(line),
      ),
    );

    expect(printed.single, contains('info'));
    expect(printed.single, contains('booted'));
  });

  test('appends the error and stack trace when present', () {
    final printed = <String>[];
    final stackTrace = StackTrace.current;

    runZoned(
      () => const PrintingLogObserver().onLog(
        LogRecord(LogLevel.error, 'boom', Exception('bad'), stackTrace),
      ),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => printed.add(line),
      ),
    );

    expect(printed.single, contains('boom'));
    expect(printed.single, contains('bad'));
  });
}
