import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:archset_r2/data/models/audio_segment.dart';
import 'package:archset_r2/data/services/backend_gemini_service.dart';
import 'package:archset_r2/data/services/whisper_service.dart';
import 'package:archset_r2/domain/services/audio_service.dart';
import 'package:archset_r2/presentation/audio/bloc/audio_bloc.dart';
import 'package:archset_r2/presentation/transcription/bloc/transcription_bloc.dart';

class _MockAudioService extends Mock implements AudioService {}

class _MockBackendGeminiService extends Mock implements BackendGeminiService {}

class _MockWhisperService extends Mock implements WhisperService {}

void main() {
  late _MockAudioService audioService;
  late _MockBackendGeminiService geminiService;
  late _MockWhisperService whisperService;
  late StreamController<Duration> recordingDurationController;
  late StreamController<Duration> playbackPositionController;
  late StreamController<Duration> playbackDurationController;
  late StreamController<List<double>> amplitudeController;
  late StreamController<PlayerState> playerStateController;
  late StreamController<int?> currentIndexController;

  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    audioService = _MockAudioService();
    geminiService = _MockBackendGeminiService();
    whisperService = _MockWhisperService();
    recordingDurationController = StreamController<Duration>.broadcast();
    playbackPositionController = StreamController<Duration>.broadcast();
    playbackDurationController = StreamController<Duration>.broadcast();
    amplitudeController = StreamController<List<double>>.broadcast();
    playerStateController = StreamController<PlayerState>.broadcast();
    currentIndexController = StreamController<int?>.broadcast();

    when(() => audioService.recordingDurationStream)
        .thenAnswer((_) => recordingDurationController.stream);
    when(() => audioService.playbackPositionStream)
        .thenAnswer((_) => playbackPositionController.stream);
    when(() => audioService.playbackDurationStream)
        .thenAnswer((_) => playbackDurationController.stream);
    when(() => audioService.amplitudeStream)
        .thenAnswer((_) => amplitudeController.stream);
    when(() => audioService.playerStateStream)
        .thenAnswer((_) => playerStateController.stream);
    when(() => audioService.currentIndexStream)
        .thenAnswer((_) => currentIndexController.stream);
    when(() => audioService.amplitudes).thenReturn(const []);
  });

  tearDown(() {
    recordingDurationController.close();
    playbackPositionController.close();
    playbackDurationController.close();
    amplitudeController.close();
    playerStateController.close();
    currentIndexController.close();
  });

  AudioBloc buildBloc() => AudioBloc(
        audioService: audioService,
        geminiService: geminiService,
        whisperService: whisperService,
      );

  group('recording', () {
    blocTest<AudioBloc, AudioState>(
      'start: emits recording state on success',
      setUp: () =>
          when(() => audioService.startRecording()).thenAnswer((_) async => true),
      build: buildBloc,
      act: (bloc) => bloc.add(
        const AudioRecordingToggleRequested(
          engine: TranscriptionEngine.gemini,
          languageCode: 'en',
        ),
      ),
      expect: () => [
        predicate<AudioState>(
          (s) =>
              s.recordingState == AudioRecordingState.recording &&
              s.recordingDuration == Duration.zero,
        ),
      ],
    );

    blocTest<AudioBloc, AudioState>(
      'start: emits an error message on failure',
      setUp: () => when(() => audioService.startRecording())
          .thenAnswer((_) async => false),
      build: buildBloc,
      act: (bloc) => bloc.add(
        const AudioRecordingToggleRequested(
          engine: TranscriptionEngine.gemini,
          languageCode: 'en',
        ),
      ),
      expect: () => [
        predicate<AudioState>((s) => s.errorMessage != null),
      ],
    );

    blocTest<AudioBloc, AudioState>(
      'stop: creates a segment, saves it, and transcribes via gemini',
      setUp: () {
        when(() => audioService.stopRecording())
            .thenAnswer((_) async => '/tmp/rec1.m4a');
        when(() => audioService.loadPlaylist(any()))
            .thenAnswer((_) async {});
        when(() => geminiService.transcribeAudio(any()))
            .thenAnswer((_) async => 'hello world');
      },
      build: () {
        when(() => audioService.startRecording())
            .thenAnswer((_) async => true);
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(
          const AudioRecordingToggleRequested(
            engine: TranscriptionEngine.gemini,
            languageCode: 'en',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(
          const AudioRecordingToggleRequested(
            engine: TranscriptionEngine.gemini,
            languageCode: 'en',
          ),
        );
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.segments, hasLength(1));
        expect(bloc.state.segments.single.name, 'Voice 001');
        expect(bloc.state.recordingState, AudioRecordingState.recorded);
        expect(bloc.state.isTranscribing, isFalse);
        expect(bloc.state.lastTranscription, 'hello world');
        verify(() => geminiService.transcribeAudio('/tmp/rec1.m4a')).called(1);
        verifyNever(() => whisperService.transcribe(any(), language: any(named: 'language')));
      },
    );

    blocTest<AudioBloc, AudioState>(
      'stop: transcribes via whisper with the given language when engine is whisper',
      setUp: () {
        when(() => audioService.stopRecording())
            .thenAnswer((_) async => '/tmp/rec1.m4a');
        when(() => audioService.loadPlaylist(any())).thenAnswer((_) async {});
        when(() => whisperService.transcribe(any(), language: any(named: 'language')))
            .thenAnswer((_) async => 'bonjour');
      },
      build: () {
        when(() => audioService.startRecording())
            .thenAnswer((_) async => true);
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(
          const AudioRecordingToggleRequested(
            engine: TranscriptionEngine.whisper,
            languageCode: 'fr',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(
          const AudioRecordingToggleRequested(
            engine: TranscriptionEngine.whisper,
            languageCode: 'fr',
          ),
        );
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.lastTranscription, 'bonjour');
        verify(() => whisperService.transcribe('/tmp/rec1.m4a', language: 'fr'))
            .called(1);
      },
    );

    blocTest<AudioBloc, AudioState>(
      'stop: emits an error when the service returns no path',
      setUp: () => when(() => audioService.stopRecording())
          .thenAnswer((_) async => null),
      build: () {
        when(() => audioService.startRecording())
            .thenAnswer((_) async => true);
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(
          const AudioRecordingToggleRequested(
            engine: TranscriptionEngine.gemini,
            languageCode: 'en',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(
          const AudioRecordingToggleRequested(
            engine: TranscriptionEngine.gemini,
            languageCode: 'en',
          ),
        );
      },
      wait: const Duration(milliseconds: 20),
      verify: (bloc) {
        expect(bloc.state.recordingState, AudioRecordingState.idle);
        expect(bloc.state.errorMessage, isNotNull);
      },
    );
  });

  group('playback', () {
    blocTest<AudioBloc, AudioState>(
      'AudioPlayRequested plays when a path is loaded',
      seed: () => const AudioState(audioPath: '/tmp/a.m4a'),
      setUp: () => when(() => audioService.playAudio()).thenAnswer((_) async {}),
      build: buildBloc,
      act: (bloc) => bloc.add(const AudioPlayRequested()),
      expect: () => [
        const AudioState(
          audioPath: '/tmp/a.m4a',
          playbackState: AudioPlaybackState.playing,
        ),
      ],
      verify: (_) => verify(() => audioService.playAudio()).called(1),
    );

    blocTest<AudioBloc, AudioState>(
      'AudioPlayRequested is a no-op without a loaded path',
      build: buildBloc,
      act: (bloc) => bloc.add(const AudioPlayRequested()),
      expect: () => [],
      verify: (_) => verifyNever(() => audioService.playAudio()),
    );

    blocTest<AudioBloc, AudioState>(
      'AudioPlayPauseToggled pauses while playing',
      seed: () => const AudioState(
        audioPath: '/tmp/a.m4a',
        playbackState: AudioPlaybackState.playing,
      ),
      setUp: () => when(() => audioService.pauseAudio()).thenAnswer((_) async {}),
      build: buildBloc,
      act: (bloc) => bloc.add(const AudioPlayPauseToggled()),
      expect: () => [
        const AudioState(
          audioPath: '/tmp/a.m4a',
          playbackState: AudioPlaybackState.paused,
        ),
      ],
    );

    blocTest<AudioBloc, AudioState>(
      'AudioPlayPauseToggled plays while paused',
      seed: () => const AudioState(
        audioPath: '/tmp/a.m4a',
        playbackState: AudioPlaybackState.paused,
      ),
      setUp: () => when(() => audioService.playAudio()).thenAnswer((_) async {}),
      build: buildBloc,
      act: (bloc) => bloc.add(const AudioPlayPauseToggled()),
      expect: () => [
        const AudioState(
          audioPath: '/tmp/a.m4a',
          playbackState: AudioPlaybackState.playing,
        ),
      ],
    );

    blocTest<AudioBloc, AudioState>(
      'AudioSeekRequested seeks the service and updates position',
      setUp: () => when(() => audioService.seekTo(any())).thenAnswer((_) async {}),
      build: buildBloc,
      act: (bloc) => bloc.add(const AudioSeekRequested(Duration(seconds: 5))),
      expect: () => [
        const AudioState(playbackPosition: Duration(seconds: 5)),
      ],
      verify: (_) =>
          verify(() => audioService.seekTo(const Duration(seconds: 5))).called(1),
    );

    blocTest<AudioBloc, AudioState>(
      'AudioSpeedCycleRequested cycles 1.0 -> 1.5',
      setUp: () => when(() => audioService.setSpeed(any())).thenAnswer((_) async {}),
      build: buildBloc,
      act: (bloc) => bloc.add(const AudioSpeedCycleRequested()),
      expect: () => [const AudioState(playbackSpeed: 1.5)],
      verify: (_) => verify(() => audioService.setSpeed(1.5)).called(1),
    );

    blocTest<AudioBloc, AudioState>(
      'AudioSkipForwardRequested delegates to the service without emitting',
      setUp: () =>
          when(() => audioService.skipForward(any())).thenAnswer((_) async {}),
      build: buildBloc,
      act: (bloc) => bloc.add(const AudioSkipForwardRequested()),
      expect: () => [],
      verify: (_) => verify(
        () => audioService.skipForward(const Duration(seconds: 10)),
      ).called(1),
    );

    blocTest<AudioBloc, AudioState>(
      'AudioSkipBackwardRequested delegates to the service without emitting',
      setUp: () =>
          when(() => audioService.skipBackward(any())).thenAnswer((_) async {}),
      build: buildBloc,
      act: (bloc) => bloc.add(const AudioSkipBackwardRequested()),
      expect: () => [],
      verify: (_) => verify(
        () => audioService.skipBackward(const Duration(seconds: 10)),
      ).called(1),
    );
  });

  group('segments popup and player expansion', () {
    blocTest<AudioBloc, AudioState>(
      'AudioSegmentsPopupShown sets the flag',
      build: buildBloc,
      act: (bloc) => bloc.add(const AudioSegmentsPopupShown()),
      expect: () => [const AudioState(isSegmentsPopupVisible: true)],
    );

    blocTest<AudioBloc, AudioState>(
      'AudioSegmentsPopupHidden clears the flag',
      seed: () => const AudioState(isSegmentsPopupVisible: true),
      build: buildBloc,
      act: (bloc) => bloc.add(const AudioSegmentsPopupHidden()),
      expect: () => [const AudioState()],
    );

    blocTest<AudioBloc, AudioState>(
      'AudioPlayerExpansionToggled flips isPlayerExpanded',
      build: buildBloc,
      act: (bloc) => bloc.add(const AudioPlayerExpansionToggled()),
      expect: () => [const AudioState(isPlayerExpanded: false)],
    );
  });

  group('segment management', () {
    final segment0 = AudioSegment(
      id: 's0',
      name: 'Voice 001',
      filePath: '/tmp/s0.m4a',
      duration: const Duration(seconds: 10),
      recordedAt: DateTime(2026, 1, 1),
      startPosition: Duration.zero,
    );
    final segment1 = AudioSegment(
      id: 's1',
      name: 'Voice 002',
      filePath: '/tmp/s1.m4a',
      duration: const Duration(seconds: 20),
      recordedAt: DateTime(2026, 1, 1),
      startPosition: const Duration(seconds: 10),
    );

    blocTest<AudioBloc, AudioState>(
      'AudioSegmentSeekRequested seeks by index and updates position',
      seed: () => AudioState(segments: [segment0, segment1]),
      setUp: () =>
          when(() => audioService.seekToIndex(any())).thenAnswer((_) async {}),
      build: buildBloc,
      act: (bloc) => bloc.add(const AudioSegmentSeekRequested(1)),
      verify: (bloc) {
        expect(bloc.state.currentSegmentIndex, 1);
        expect(bloc.state.playbackPosition, const Duration(seconds: 10));
        verify(() => audioService.seekToIndex(1)).called(1);
      },
    );

    blocTest<AudioBloc, AudioState>(
      'AudioSegmentRenamed updates the segment name in place',
      seed: () => AudioState(segments: [segment0, segment1]),
      build: buildBloc,
      act: (bloc) => bloc.add(const AudioSegmentRenamed(0, 'Intro')),
      verify: (bloc) {
        expect(bloc.state.segments[0].name, 'Intro');
        expect(bloc.state.segments[1].name, 'Voice 002');
      },
    );

    blocTest<AudioBloc, AudioState>(
      'AudioSegmentDeleted recalculates start positions of remaining segments',
      seed: () => AudioState(
        segments: [segment0, segment1],
        playbackTotalDuration: const Duration(seconds: 30),
        audioPath: '/tmp/meta.json',
      ),
      setUp: () {
        when(() => audioService.loadPlaylist(any())).thenAnswer((_) async {});
        when(() => audioService.stopAudio()).thenAnswer((_) async {});
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const AudioSegmentDeleted(0)),
      verify: (bloc) {
        expect(bloc.state.segments, hasLength(1));
        expect(bloc.state.segments.single.id, 's1');
        expect(bloc.state.segments.single.startPosition, Duration.zero);
        expect(bloc.state.playbackTotalDuration, const Duration(seconds: 20));
      },
    );

    blocTest<AudioBloc, AudioState>(
      'AudioSegmentDeleted clears audioPath and resets when it was the last segment',
      seed: () => AudioState(
        segments: [segment0],
        playbackTotalDuration: const Duration(seconds: 10),
        audioPath: '/tmp/s0.m4a',
        recordingState: AudioRecordingState.recorded,
      ),
      setUp: () => when(() => audioService.stopAudio()).thenAnswer((_) async {}),
      build: buildBloc,
      act: (bloc) => bloc.add(const AudioSegmentDeleted(0)),
      expect: () => [
        const AudioState(
          segments: [],
          recordingState: AudioRecordingState.idle,
        ),
      ],
      verify: (_) => verify(() => audioService.stopAudio()).called(1),
    );
  });

  group('misc', () {
    blocTest<AudioBloc, AudioState>(
      'AudioLastTranscriptionCleared clears lastTranscription only',
      seed: () => const AudioState(
        lastTranscription: 'hi',
        playbackSpeed: 2.0,
      ),
      build: buildBloc,
      act: (bloc) => bloc.add(const AudioLastTranscriptionCleared()),
      expect: () => [const AudioState(playbackSpeed: 2.0)],
    );

    blocTest<AudioBloc, AudioState>(
      'AudioReset stops playback and restores initial state',
      seed: () => const AudioState(playbackSpeed: 2.0, audioPath: '/tmp/a.m4a'),
      setUp: () => when(() => audioService.stopAudio()).thenAnswer((_) async {}),
      build: buildBloc,
      act: (bloc) => bloc.add(const AudioReset()),
      expect: () => [const AudioState()],
    );

    blocTest<AudioBloc, AudioState>(
      'AudioInitRequested with null path is a no-op',
      build: buildBloc,
      act: (bloc) => bloc.add(const AudioInitRequested(null)),
      expect: () => [],
    );

    blocTest<AudioBloc, AudioState>(
      'AudioInitRequested with a plain file loads it directly',
      setUp: () {
        when(() => audioService.loadAudio(any())).thenAnswer((_) async {});
        when(() => audioService.totalDuration)
            .thenReturn(const Duration(seconds: 42));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const AudioInitRequested('/tmp/a.m4a')),
      expect: () => [
        const AudioState(
          recordingState: AudioRecordingState.recorded,
          audioPath: '/tmp/a.m4a',
          playbackTotalDuration: Duration(seconds: 42),
        ),
      ],
      verify: (_) => verify(() => audioService.loadAudio('/tmp/a.m4a')).called(1),
    );
  });

  group('stream-driven updates', () {
    blocTest<AudioBloc, AudioState>(
      'recording duration stream updates state',
      build: buildBloc,
      act: (bloc) async {
        recordingDurationController.add(const Duration(seconds: 3));
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [const AudioState(recordingDuration: Duration(seconds: 3))],
    );

    blocTest<AudioBloc, AudioState>(
      'player state stream completing resets position and marks completed',
      build: buildBloc,
      act: (bloc) async {
        playerStateController.add(
          PlayerState(false, ProcessingState.completed),
        );
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        const AudioState(
          playbackState: AudioPlaybackState.completed,
          playbackPosition: Duration.zero,
        ),
      ],
    );

    blocTest<AudioBloc, AudioState>(
      'player state stream playing=true marks playing',
      build: buildBloc,
      act: (bloc) async {
        playerStateController.add(PlayerState(true, ProcessingState.ready));
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [const AudioState(playbackState: AudioPlaybackState.playing)],
    );

    blocTest<AudioBloc, AudioState>(
      'player state stream playing=false while previously playing marks paused',
      seed: () => const AudioState(playbackState: AudioPlaybackState.playing),
      build: buildBloc,
      act: (bloc) async {
        playerStateController.add(PlayerState(false, ProcessingState.ready));
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [const AudioState(playbackState: AudioPlaybackState.paused)],
    );

    blocTest<AudioBloc, AudioState>(
      'current index stream updates currentSegmentIndex when non-null',
      build: buildBloc,
      act: (bloc) async {
        currentIndexController.add(2);
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [const AudioState(currentSegmentIndex: 2)],
    );
  });

  test('initial state is AudioState()', () {
    expect(buildBloc().state, const AudioState());
  });
}
