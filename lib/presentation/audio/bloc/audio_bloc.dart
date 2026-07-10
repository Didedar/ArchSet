import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:just_audio/just_audio.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/audio_segment.dart';
import '../../../data/services/backend_gemini_service.dart';
import '../../../data/services/whisper_service.dart';
import '../../../domain/services/audio_service.dart';
import '../../transcription/bloc/transcription_bloc.dart';

part 'audio_event.dart';
part 'audio_state.dart';

class AudioBloc extends Bloc<AudioEvent, AudioState> {
  AudioBloc({
    required AudioService audioService,
    required BackendGeminiService geminiService,
    required WhisperService whisperService,
  })  : _audioService = audioService,
        _geminiService = geminiService,
        _whisperService = whisperService,
        super(const AudioState()) {
    on<AudioInitRequested>(_onInitRequested, transformer: droppable());
    on<AudioRecordingToggleRequested>(
      _onRecordingToggleRequested,
      transformer: droppable(),
    );
    on<AudioPlayRequested>(_onPlayRequested, transformer: droppable());
    on<AudioPlayPauseToggled>(_onPlayPauseToggled, transformer: droppable());
    on<AudioSeekRequested>(_onSeekRequested, transformer: droppable());
    on<AudioSpeedCycleRequested>(
      _onSpeedCycleRequested,
      transformer: droppable(),
    );
    on<AudioSkipForwardRequested>(
      _onSkipForwardRequested,
      transformer: droppable(),
    );
    on<AudioSkipBackwardRequested>(
      _onSkipBackwardRequested,
      transformer: droppable(),
    );
    on<AudioSegmentsPopupShown>(
      _onSegmentsPopupShown,
      transformer: droppable(),
    );
    on<AudioSegmentsPopupHidden>(
      _onSegmentsPopupHidden,
      transformer: droppable(),
    );
    on<AudioPlayerExpansionToggled>(
      _onPlayerExpansionToggled,
      transformer: droppable(),
    );
    on<AudioSegmentSeekRequested>(
      _onSegmentSeekRequested,
      transformer: droppable(),
    );
    on<AudioSegmentRenamed>(_onSegmentRenamed, transformer: droppable());
    on<AudioSegmentDeleted>(_onSegmentDeleted, transformer: droppable());
    on<AudioLastTranscriptionCleared>(
      _onLastTranscriptionCleared,
      transformer: droppable(),
    );
    on<AudioReset>(_onReset, transformer: droppable());
    on<_RecordingDurationUpdated>(
      _onRecordingDurationUpdated,
      transformer: sequential(),
    );
    on<_PlaybackPositionUpdated>(
      _onPlaybackPositionUpdated,
      transformer: sequential(),
    );
    on<_PlaybackDurationUpdated>(
      _onPlaybackDurationUpdated,
      transformer: sequential(),
    );
    on<_AmplitudesUpdated>(_onAmplitudesUpdated, transformer: sequential());
    on<_PlayerStateUpdated>(_onPlayerStateUpdated, transformer: sequential());
    on<_CurrentIndexUpdated>(
      _onCurrentIndexUpdated,
      transformer: sequential(),
    );

    _setupListeners();
  }

  final AudioService _audioService;
  final BackendGeminiService _geminiService;
  final WhisperService _whisperService;

  StreamSubscription<Duration>? _recordingDurationSub;
  StreamSubscription<Duration>? _playbackPositionSub;
  StreamSubscription<Duration>? _playbackDurationSub;
  StreamSubscription<List<double>>? _amplitudeSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<int?>? _currentIndexSub;

  void _setupListeners() {
    _recordingDurationSub = _audioService.recordingDurationStream.listen(
      (duration) => add(_RecordingDurationUpdated(duration)),
    );
    _playbackPositionSub = _audioService.playbackPositionStream.listen(
      (position) => add(_PlaybackPositionUpdated(position)),
    );
    _playbackDurationSub = _audioService.playbackDurationStream.listen(
      (duration) => add(_PlaybackDurationUpdated(duration)),
    );
    _amplitudeSub = _audioService.amplitudeStream.listen(
      (amplitudes) => add(_AmplitudesUpdated(amplitudes)),
    );
    _playerStateSub = _audioService.playerStateStream.listen(
      (playerState) => add(_PlayerStateUpdated(playerState)),
    );
    _currentIndexSub = _audioService.currentIndexStream.listen(
      (index) => add(_CurrentIndexUpdated(index)),
    );
  }

  Future<void> _onInitRequested(
    AudioInitRequested event,
    Emitter<AudioState> emit,
  ) async {
    final path = event.path;
    if (path == null) return;

    if (path.endsWith('.json')) {
      await _loadSegmentsFromJson(path, emit);
    } else {
      await _audioService.loadAudio(path);
      emit(
        state.copyWith(
          recordingState: AudioRecordingState.recorded,
          audioPath: path,
          playbackTotalDuration: _audioService.totalDuration ?? Duration.zero,
        ),
      );
    }
  }

  Future<void> _loadSegmentsFromJson(
    String jsonPath,
    Emitter<AudioState> emit,
  ) async {
    try {
      final file = File(jsonPath);
      if (!await file.exists()) return;

      final jsonString = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final segments =
          jsonList.map((e) => AudioSegment.fromJson(e)).toList();
      final totalDuration = segments.fold<Duration>(
        Duration.zero,
        (sum, segment) => sum + segment.duration,
      );

      final paths = segments.map((s) => s.filePath).toList();
      await _audioService.loadPlaylist(paths);

      emit(
        state.copyWith(
          recordingState: AudioRecordingState.recorded,
          audioPath: jsonPath,
          segments: segments,
          playbackTotalDuration: totalDuration,
          segmentCounter: segments.length,
        ),
      );
    } catch (_) {
      // Matches the original: a corrupt/missing metadata file is not
      // surfaced to the user, just left unloaded.
    }
  }

  Future<void> _onRecordingToggleRequested(
    AudioRecordingToggleRequested event,
    Emitter<AudioState> emit,
  ) async {
    if (state.isRecording) {
      await _stopRecording(event.engine, event.languageCode, emit);
    } else {
      await _startRecording(emit);
    }
  }

  Future<void> _startRecording(Emitter<AudioState> emit) async {
    final success = await _audioService.startRecording();
    if (success) {
      emit(
        state.copyWith(
          recordingState: AudioRecordingState.recording,
          recordingDuration: Duration.zero,
          amplitudes: const [],
        ),
      );
    } else {
      emit(
        state.copyWith(
          errorMessage:
              'Failed to start recording. Check microphone permission.',
        ),
      );
    }
  }

  Future<void> _stopRecording(
    TranscriptionEngine engine,
    String languageCode,
    Emitter<AudioState> emit,
  ) async {
    final path = await _audioService.stopRecording();
    final recordingDuration = state.recordingDuration;

    if (path == null) {
      emit(
        state.copyWith(
          recordingState: AudioRecordingState.idle,
          errorMessage: 'Failed to save recording.',
        ),
      );
      return;
    }

    final totalPreviousDuration = state.segments.fold<Duration>(
      Duration.zero,
      (sum, segment) => sum + segment.duration,
    );
    final newSegmentIndex = state.segmentCounter + 1;
    final segmentName = 'Voice ${newSegmentIndex.toString().padLeft(3, '0')}';
    final newSegment = AudioSegment(
      id: const Uuid().v4(),
      name: segmentName,
      filePath: path,
      duration: recordingDuration,
      recordedAt: DateTime.now(),
      startPosition: totalPreviousDuration,
    );
    final updatedSegments = [...state.segments, newSegment];
    final newTotalDuration = updatedSegments.fold<Duration>(
      Duration.zero,
      (sum, segment) => sum + segment.duration,
    );

    emit(
      state.copyWith(
        recordingState: AudioRecordingState.recorded,
        playbackState: AudioPlaybackState.idle,
        playbackTotalDuration: newTotalDuration,
        amplitudes: _audioService.amplitudes,
        segments: updatedSegments,
        segmentCounter: newSegmentIndex,
      ),
    );

    final jsonPath = await _saveSegmentsMetadata();
    if (jsonPath != null) {
      emit(state.copyWith(audioPath: jsonPath));
    }

    final paths = updatedSegments.map((s) => s.filePath).toList();
    await _audioService.loadPlaylist(paths);

    emit(state.copyWith(isTranscribing: true));

    String? transcription;
    try {
      if (engine == TranscriptionEngine.whisper) {
        transcription = await _whisperService.transcribe(
          path,
          language: languageCode,
        );
      } else {
        transcription = await _geminiService.transcribeAudio(path);
      }
    } catch (_) {
      // Matches the original: a transcription failure is silently
      // swallowed, leaving lastTranscription null.
    }

    emit(state.copyWith(isTranscribing: false, lastTranscription: transcription));
  }

  Future<String?> _saveSegmentsMetadata() async {
    if (state.segments.isEmpty) return null;
    try {
      final firstPath = state.segments.first.filePath;
      final dir = File(firstPath).parent;
      final fileName = 'recording_${const Uuid().v4()}_meta.json';
      final file = File('${dir.path}/$fileName');
      final jsonList = state.segments.map((s) => s.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _onPlayRequested(
    AudioPlayRequested event,
    Emitter<AudioState> emit,
  ) async {
    if (state.audioPath == null) return;

    if (state.playbackState == AudioPlaybackState.completed) {
      await _audioService.seekTo(Duration.zero);
    }

    emit(state.copyWith(playbackState: AudioPlaybackState.playing));
    await _audioService.playAudio();
  }

  Future<void> _onPlayPauseToggled(
    AudioPlayPauseToggled event,
    Emitter<AudioState> emit,
  ) async {
    if (state.isPlaying) {
      emit(state.copyWith(playbackState: AudioPlaybackState.paused));
      await _audioService.pauseAudio();
    } else {
      await _onPlayRequested(const AudioPlayRequested(), emit);
    }
  }

  Future<void> _onSeekRequested(
    AudioSeekRequested event,
    Emitter<AudioState> emit,
  ) async {
    await _audioService.seekTo(event.position);
    emit(state.copyWith(playbackPosition: event.position));
  }

  static const List<double> _speeds = [0.5, 1.0, 1.5, 2.0];

  Future<void> _onSpeedCycleRequested(
    AudioSpeedCycleRequested event,
    Emitter<AudioState> emit,
  ) async {
    final currentIndex = _speeds.indexOf(state.playbackSpeed);
    final nextSpeed = _speeds[(currentIndex + 1) % _speeds.length];
    await _audioService.setSpeed(nextSpeed);
    emit(state.copyWith(playbackSpeed: nextSpeed));
  }

  Future<void> _onSkipForwardRequested(
    AudioSkipForwardRequested event,
    Emitter<AudioState> emit,
  ) async {
    await _audioService.skipForward(const Duration(seconds: 10));
  }

  Future<void> _onSkipBackwardRequested(
    AudioSkipBackwardRequested event,
    Emitter<AudioState> emit,
  ) async {
    await _audioService.skipBackward(const Duration(seconds: 10));
  }

  void _onSegmentsPopupShown(
    AudioSegmentsPopupShown event,
    Emitter<AudioState> emit,
  ) {
    emit(state.copyWith(isSegmentsPopupVisible: true));
  }

  void _onSegmentsPopupHidden(
    AudioSegmentsPopupHidden event,
    Emitter<AudioState> emit,
  ) {
    emit(state.copyWith(isSegmentsPopupVisible: false));
  }

  void _onPlayerExpansionToggled(
    AudioPlayerExpansionToggled event,
    Emitter<AudioState> emit,
  ) {
    emit(state.copyWith(isPlayerExpanded: !state.isPlayerExpanded));
  }

  Future<void> _onSegmentSeekRequested(
    AudioSegmentSeekRequested event,
    Emitter<AudioState> emit,
  ) async {
    final index = event.index;
    if (index < 0 || index >= state.segments.length) return;

    await _audioService.seekToIndex(index);
    emit(
      state.copyWith(
        playbackPosition: state.segments[index].startPosition,
        currentSegmentIndex: index,
      ),
    );
  }

  void _onSegmentRenamed(
    AudioSegmentRenamed event,
    Emitter<AudioState> emit,
  ) {
    final index = event.index;
    if (index < 0 || index >= state.segments.length) return;
    if (event.name.trim().isEmpty) return;

    final updatedSegments = List<AudioSegment>.from(state.segments);
    updatedSegments[index] = updatedSegments[index].copyWith(
      name: event.name.trim(),
    );
    emit(state.copyWith(segments: updatedSegments));
  }

  Future<void> _onSegmentDeleted(
    AudioSegmentDeleted event,
    Emitter<AudioState> emit,
  ) async {
    final index = event.index;
    if (index < 0 || index >= state.segments.length) return;

    final updatedSegments = List<AudioSegment>.from(state.segments);
    final deletedSegment = updatedSegments.removeAt(index);
    final wasPlayingDeletedSegment = index == state.currentSegmentIndex;

    Duration cumulative = Duration.zero;
    for (var i = 0; i < updatedSegments.length; i++) {
      updatedSegments[i] = updatedSegments[i].copyWith(
        startPosition: cumulative,
      );
      cumulative += updatedSegments[i].duration;
    }

    try {
      final file = File(deletedSegment.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Continue anyway: the segment is already removed from the list.
    }

    if (updatedSegments.isEmpty) {
      await _audioService.stopAudio();
      final oldAudioPath = state.audioPath;
      emit(
        state.copyWith(
          segments: const [],
          recordingState: AudioRecordingState.idle,
          clearAudioPath: true,
          playbackState: AudioPlaybackState.idle,
          playbackTotalDuration: Duration.zero,
          playbackPosition: Duration.zero,
          currentSegmentIndex: 0,
        ),
      );
      if (oldAudioPath != null && oldAudioPath.endsWith('.json')) {
        try {
          final file = File(oldAudioPath);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      return;
    }

    final newAudioPath = state.audioPath;
    emit(
      state.copyWith(
        segments: updatedSegments,
        playbackTotalDuration: cumulative,
        audioPath: newAudioPath,
      ),
    );

    await _saveSegmentsMetadata();

    final paths = updatedSegments.map((s) => s.filePath).toList();
    await _audioService.loadPlaylist(paths);

    if (wasPlayingDeletedSegment) {
      await _audioService.stopAudio();
    } else if (state.currentSegmentIndex > index) {
      emit(
        state.copyWith(currentSegmentIndex: state.currentSegmentIndex - 1),
      );
    }
  }

  void _onLastTranscriptionCleared(
    AudioLastTranscriptionCleared event,
    Emitter<AudioState> emit,
  ) {
    emit(state.copyWith(clearLastTranscription: true));
  }

  void _onReset(AudioReset event, Emitter<AudioState> emit) {
    _audioService.stopAudio();
    emit(const AudioState());
  }

  void _onRecordingDurationUpdated(
    _RecordingDurationUpdated event,
    Emitter<AudioState> emit,
  ) {
    emit(state.copyWith(recordingDuration: event.duration));
  }

  void _onPlaybackPositionUpdated(
    _PlaybackPositionUpdated event,
    Emitter<AudioState> emit,
  ) {
    emit(state.copyWith(playbackPosition: event.position));
  }

  void _onPlaybackDurationUpdated(
    _PlaybackDurationUpdated event,
    Emitter<AudioState> emit,
  ) {
    emit(state.copyWith(playbackTotalDuration: event.duration));
  }

  void _onAmplitudesUpdated(
    _AmplitudesUpdated event,
    Emitter<AudioState> emit,
  ) {
    emit(state.copyWith(amplitudes: event.amplitudes));
  }

  void _onPlayerStateUpdated(
    _PlayerStateUpdated event,
    Emitter<AudioState> emit,
  ) {
    final playerState = event.playerState;
    if (playerState.processingState == ProcessingState.completed) {
      emit(
        state.copyWith(
          playbackState: AudioPlaybackState.completed,
          playbackPosition: Duration.zero,
        ),
      );
    } else if (playerState.playing) {
      emit(state.copyWith(playbackState: AudioPlaybackState.playing));
    } else if (state.playbackState == AudioPlaybackState.playing) {
      emit(state.copyWith(playbackState: AudioPlaybackState.paused));
    }
  }

  void _onCurrentIndexUpdated(
    _CurrentIndexUpdated event,
    Emitter<AudioState> emit,
  ) {
    if (event.index != null) {
      emit(state.copyWith(currentSegmentIndex: event.index!));
    }
  }

  @override
  Future<void> close() async {
    await _recordingDurationSub?.cancel();
    await _playbackPositionSub?.cancel();
    await _playbackDurationSub?.cancel();
    await _amplitudeSub?.cancel();
    await _playerStateSub?.cancel();
    await _currentIndexSub?.cancel();
    _audioService.dispose();
    return super.close();
  }
}
