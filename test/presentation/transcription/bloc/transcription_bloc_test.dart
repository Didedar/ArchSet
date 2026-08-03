import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:archset_r2/data/services/whisper_service.dart';
import 'package:archset_r2/presentation/transcription/bloc/transcription_bloc.dart';

class _MockWhisperService extends Mock implements WhisperService {}

void main() {
  late _MockWhisperService whisperService;

  setUp(() {
    whisperService = _MockWhisperService();
  });

  blocTest<TranscriptionBloc, TranscriptionState>(
    'TranscriptionModelStatusChecked emits isModelDownloaded from the service',
    setUp: () => when(
      () => whisperService.isModelDownloaded(),
    ).thenAnswer((_) async => true),
    build: () => TranscriptionBloc(whisperService: whisperService),
    act: (bloc) => bloc.add(const TranscriptionModelStatusChecked()),
    expect: () => [const TranscriptionState(isModelDownloaded: true)],
  );

  blocTest<TranscriptionBloc, TranscriptionState>(
    'TranscriptionEngineChanged emits the new engine',
    build: () => TranscriptionBloc(whisperService: whisperService),
    act: (bloc) =>
        bloc.add(const TranscriptionEngineChanged(TranscriptionEngine.whisper)),
    expect: () => [
      const TranscriptionState(engine: TranscriptionEngine.whisper),
    ],
  );

  blocTest<TranscriptionBloc, TranscriptionState>(
    'TranscriptionModelDownloadRequested reports progress then completes',
    setUp: () {
      when(
        () =>
            whisperService.downloadModel(onProgress: any(named: 'onProgress')),
      ).thenAnswer((invocation) async {
        final onProgress =
            invocation.namedArguments[#onProgress] as void Function(double);
        onProgress(0.5);
      });
      when(() => whisperService.init()).thenAnswer((_) async {});
    },
    build: () => TranscriptionBloc(whisperService: whisperService),
    act: (bloc) => bloc.add(const TranscriptionModelDownloadRequested()),
    expect: () => [
      const TranscriptionState(isDownloading: true),
      const TranscriptionState(isDownloading: true, downloadProgress: 0.5),
      const TranscriptionState(isModelDownloaded: true, downloadProgress: 1.0),
    ],
    verify: (_) {
      verify(() => whisperService.init()).called(1);
    },
  );

  blocTest<TranscriptionBloc, TranscriptionState>(
    'TranscriptionModelDownloadRequested resets downloading flags on failure',
    setUp: () => when(
      () => whisperService.downloadModel(onProgress: any(named: 'onProgress')),
    ).thenThrow(Exception('network error')),
    build: () => TranscriptionBloc(whisperService: whisperService),
    act: (bloc) => bloc.add(const TranscriptionModelDownloadRequested()),
    expect: () => [
      const TranscriptionState(isDownloading: true),
      const TranscriptionState(),
    ],
    errors: () => [isA<Exception>()],
  );

  blocTest<TranscriptionBloc, TranscriptionState>(
    'a second download request is dropped while one is in flight',
    setUp: () {
      when(
        () =>
            whisperService.downloadModel(onProgress: any(named: 'onProgress')),
      ).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      when(() => whisperService.init()).thenAnswer((_) async {});
    },
    build: () => TranscriptionBloc(whisperService: whisperService),
    act: (bloc) {
      bloc.add(const TranscriptionModelDownloadRequested());
      bloc.add(const TranscriptionModelDownloadRequested());
    },
    wait: const Duration(milliseconds: 50),
    verify: (_) {
      verify(
        () =>
            whisperService.downloadModel(onProgress: any(named: 'onProgress')),
      ).called(1);
    },
  );

  test('initial state is TranscriptionState()', () {
    expect(
      TranscriptionBloc(whisperService: whisperService).state,
      const TranscriptionState(),
    );
  });
}
