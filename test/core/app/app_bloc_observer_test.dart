import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/core/app/app_bloc_observer.dart';
import 'package:archset_r2/core/logging/logger.dart';

class _FakeEvent {}

class _FakeState extends Equatable {
  const _FakeState(this.value);
  final int value;
  @override
  List<Object?> get props => [value];
}

class _FakeBloc extends Bloc<_FakeEvent, _FakeState> {
  _FakeBloc() : super(const _FakeState(0)) {
    on<_FakeEvent>((event, emit) => emit(const _FakeState(1)));
  }
}

class _RecordingObserver implements LogObserver {
  final records = <LogRecord>[];

  @override
  void onLog(LogRecord record) => records.add(record);
}

void main() {
  test('logs every bloc state transition at info level', () async {
    final logger = Logger();
    final observer = _RecordingObserver();
    logger.addObserver(observer);
    Bloc.observer = AppBlocObserver(logger);

    final bloc = _FakeBloc();
    bloc.add(_FakeEvent());
    await bloc.stream.first;
    await bloc.close();

    expect(
      observer.records.any(
        (r) => r.level == LogLevel.info && r.message.contains('_FakeBloc'),
      ),
      isTrue,
    );
  });

  test(
    'logs bloc errors at error level with the error and stack trace',
    () async {
      final logger = Logger();
      final observer = _RecordingObserver();
      logger.addObserver(observer);
      final appObserver = AppBlocObserver(logger);
      final bloc = _FakeBloc();
      final stackTrace = StackTrace.current;

      appObserver.onError(bloc, Exception('boom'), stackTrace);

      final record = observer.records.singleWhere(
        (r) => r.level == LogLevel.error,
      );
      expect(record.message, contains('_FakeBloc'));
      expect(record.error, isException);
      expect(record.stackTrace, stackTrace);

      await bloc.close();
    },
  );
}
