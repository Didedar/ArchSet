import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:uuid/uuid.dart';
import '../../domain/services/audio_service.dart';
import '../../data/services/backend_gemini_service.dart';
import '../../data/services/whisper_service.dart';
import '../../data/models/audio_segment.dart';
import '../../data/services/api_service.dart'; // Import ApiService
import '../../data/services/auth_service.dart'; // Import AuthService

import 'transcription_provider.dart'; // Import TranscriptionProvider
import 'locale_provider.dart'; // Import LocaleProvider

/// Audio recording state
enum AudioRecordingState { idle, recording, recorded }

/// Audio playback state
enum AudioPlaybackState { idle, loading, playing, paused, completed }

/// Audio state model
class AudioState {
  final AudioRecordingState recordingState;
  final AudioPlaybackState playbackState;
  final Duration recordingDuration;
  final Duration playbackPosition;
  final Duration playbackTotalDuration;
  final String? audioPath;
  final List<double> amplitudes;
  final double playbackSpeed;
  final String? errorMessage;

  // Multi-segment support
  final List<AudioSegment> segments;
  final bool isSegmentsPopupVisible;
  final int? editingSegmentIndex;
  final int segmentCounter; // For auto-naming "Voice 001", "Voice 002", etc.
  final bool isPlayerExpanded;
  final int currentSegmentIndex; // Explicitly tracked active segment
  final bool isTranscribing;
  final String? lastTranscription;

  const AudioState({
    this.recordingState = AudioRecordingState.idle,
    this.playbackState = AudioPlaybackState.idle,
    this.recordingDuration = Duration.zero,
    this.playbackPosition = Duration.zero,
    this.playbackTotalDuration = Duration.zero,
    this.audioPath,
    this.amplitudes = const [],
    this.playbackSpeed = 1.0,
    this.errorMessage,
    this.segments = const [],
    this.isSegmentsPopupVisible = false,
    this.editingSegmentIndex,
    this.segmentCounter = 0,
    this.isPlayerExpanded = true,
    this.currentSegmentIndex = 0,
    this.isTranscribing = false,
    this.lastTranscription,
  });

  bool get isRecording => recordingState == AudioRecordingState.recording;
  bool get hasRecording =>
      recordingState == AudioRecordingState.recorded || audioPath != null;
  bool get isPlaying => playbackState == AudioPlaybackState.playing;
  bool get hasSegments => segments.isNotEmpty;
  bool get isEditing => editingSegmentIndex != null;

  /// Get the index of the currently playing segment based on playback position
  int get activeSegmentIndex {
    if (segments.isEmpty) return -1;
    // Prefer the explicit current index from player
    if (currentSegmentIndex >= 0 && currentSegmentIndex < segments.length) {
      return currentSegmentIndex;
    }
    return 0;
  }

  AudioState copyWith({
    AudioRecordingState? recordingState,
    AudioPlaybackState? playbackState,
    Duration? recordingDuration,
    Duration? playbackPosition,
    Duration? playbackTotalDuration,
    String? audioPath,
    List<double>? amplitudes,
    double? playbackSpeed,
    String? errorMessage,
    List<AudioSegment>? segments,
    bool? isSegmentsPopupVisible,
    int? editingSegmentIndex,
    bool clearEditingSegment = false,
    int? segmentCounter,
    bool? isPlayerExpanded,
    int? currentSegmentIndex,
    bool clearAudioPath = false,
    bool? isTranscribing,
    String? lastTranscription,
    bool clearLastTranscription = false,
  }) {
    return AudioState(
      recordingState: recordingState ?? this.recordingState,
      playbackState: playbackState ?? this.playbackState,
      recordingDuration: recordingDuration ?? this.recordingDuration,
      playbackPosition: playbackPosition ?? this.playbackPosition,
      playbackTotalDuration:
          playbackTotalDuration ?? this.playbackTotalDuration,
      audioPath: clearAudioPath ? null : (audioPath ?? this.audioPath),
      amplitudes: amplitudes ?? this.amplitudes,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      errorMessage: errorMessage,
      segments: segments ?? this.segments,
      isSegmentsPopupVisible:
          isSegmentsPopupVisible ?? this.isSegmentsPopupVisible,
      editingSegmentIndex: clearEditingSegment
          ? null
          : (editingSegmentIndex ?? this.editingSegmentIndex),
      segmentCounter: segmentCounter ?? this.segmentCounter,
      isPlayerExpanded: isPlayerExpanded ?? this.isPlayerExpanded,
      currentSegmentIndex: currentSegmentIndex ?? this.currentSegmentIndex,
      isTranscribing: isTranscribing ?? this.isTranscribing,
      lastTranscription: clearLastTranscription
          ? null
          : (lastTranscription ?? this.lastTranscription),
    );
  }
}

/// Audio state notifier
class AudioNotifier extends StateNotifier<AudioState> {
  final Ref _ref;
  final AudioService _audioService;
  final BackendGeminiService _geminiService;
  final WhisperService _whisperService;
  StreamSubscription<Duration>? _recordingDurationSub;
  StreamSubscription<Duration>? _playbackPositionSub;
  StreamSubscription<Duration>? _playbackDurationSub;
  StreamSubscription<List<double>>? _amplitudeSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<int?>? _currentIndexSub;

  AudioNotifier(
    this._ref,
    this._audioService,
    this._geminiService,
    this._whisperService,
  ) : super(const AudioState()) {
    _setupListeners();
  }

  void _setupListeners() {
    _recordingDurationSub = _audioService.recordingDurationStream.listen((
      duration,
    ) {
      state = state.copyWith(recordingDuration: duration);
    });

    _playbackPositionSub = _audioService.playbackPositionStream.listen((
      position,
    ) {
      state = state.copyWith(playbackPosition: position);
    });

    _playbackDurationSub = _audioService.playbackDurationStream.listen((
      duration,
    ) {
      state = state.copyWith(playbackTotalDuration: duration);
    });

    _amplitudeSub = _audioService.amplitudeStream.listen((amplitudes) {
      state = state.copyWith(amplitudes: amplitudes);
    });

    _playerStateSub = _audioService.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        state = state.copyWith(
          playbackState: AudioPlaybackState.completed,
          playbackPosition: Duration.zero,
        );
      } else if (playerState.playing) {
        state = state.copyWith(playbackState: AudioPlaybackState.playing);
      } else if (state.playbackState == AudioPlaybackState.playing) {
        state = state.copyWith(playbackState: AudioPlaybackState.paused);
      }
    });

    _currentIndexSub = _audioService.currentIndexStream.listen((index) {
      if (index != null) {
        state = state.copyWith(currentSegmentIndex: index);
      }
    });
  }

  /// Start recording
  Future<void> startRecording() async {
    debugPrint('[AudioNotifier] Starting recording...');
    final success = await _audioService.startRecording();
    debugPrint('[AudioNotifier] Recording started: $success');
    if (success) {
      state = state.copyWith(
        recordingState: AudioRecordingState.recording,
        recordingDuration: Duration.zero,
        amplitudes: [],
      );
    } else {
      state = state.copyWith(
        errorMessage: 'Failed to start recording. Check microphone permission.',
      );
    }
  }

  /// Initialize with existing audio path
  Future<void> init(String? path) async {
    if (path == null) return;

    // Check if path is a JSON metadata file
    if (path.endsWith('.json')) {
      await _loadSegmentsFromJson(path);
    } else {
      // Legacy single file
      await _audioService.loadAudio(path);
      state = state.copyWith(
        recordingState: AudioRecordingState.recorded,
        audioPath: path,
        playbackTotalDuration: _audioService.totalDuration ?? Duration.zero,
      );
    }
  }

  /// Load segments from JSON metadata file
  Future<void> _loadSegmentsFromJson(String jsonPath) async {
    try {
      final file = File(jsonPath);
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonString);
        final segments = jsonList.map((e) => AudioSegment.fromJson(e)).toList();

        // Calculate total duration
        final totalDuration = segments.fold<Duration>(
          Duration.zero,
          (sum, segment) => sum + segment.duration,
        );

        // Load playlist
        final paths = segments.map((s) => s.filePath).toList();
        await _audioService.loadPlaylist(paths);

        state = state.copyWith(
          recordingState: AudioRecordingState.recorded,
          audioPath: jsonPath,
          segments: segments,
          playbackTotalDuration: totalDuration,
          segmentCounter: segments.length,
        );
      }
    } catch (e) {
      debugPrint('[AudioNotifier] Error loading segments: $e');
    }
  }

  /// Save segments to JSON metadata file
  Future<String?> _saveSegmentsMetadata() async {
    if (state.segments.isEmpty) return null;

    try {
      // Use the directory of the first recording
      final firstPath = state.segments.first.filePath;
      final dir = File(firstPath).parent;
      // Use a consistent name base or UUID
      final fileName = 'recording_${const Uuid().v4()}_meta.json';
      final file = File('${dir.path}/$fileName');

      final jsonList = state.segments.map((s) => s.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));

      debugPrint('[AudioNotifier] Saved metadata to: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('[AudioNotifier] Error saving metadata: $e');
      return null;
    }
  }

  /// Stop recording
  Future<void> stopRecording() async {
    debugPrint('[AudioNotifier] Stopping recording...');
    final path = await _audioService.stopRecording();
    final recordingDuration = state.recordingDuration;
    debugPrint('[AudioNotifier] Recording stopped. Path: $path');
    if (path != null) {
      // Calculate the start position for this segment
      final totalPreviousDuration = state.segments.fold<Duration>(
        Duration.zero,
        (sum, segment) => sum + segment.duration,
      );

      // Create new segment with auto-generated name
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

      // Calculate new total duration
      final newTotalDuration = updatedSegments.fold<Duration>(
        Duration.zero,
        (sum, segment) => sum + segment.duration,
      );

      // Update state first
      state = state.copyWith(
        recordingState: AudioRecordingState.recorded,
        playbackState: AudioPlaybackState.idle,
        playbackTotalDuration: newTotalDuration,
        amplitudes: _audioService.amplitudes,
        segments: updatedSegments,
        segmentCounter: newSegmentIndex,
      );

      // Save metadata and update audioPath with JSON path
      final jsonPath = await _saveSegmentsMetadata();
      if (jsonPath != null) {
        state = state.copyWith(audioPath: jsonPath);
      }

      // Load playlist for playback
      // Load playlist for playback
      final paths = updatedSegments.map((s) => s.filePath).toList();
      await _audioService.loadPlaylist(paths);

      // Start transcription
      state = state.copyWith(isTranscribing: true);
      debugPrint('[AudioNotifier] Starting transcription for $path');

      String? transcription;
      try {
        // Read current transcription settings
        // Need to import transcription_provider.dart
        final transcriptionState = _ref.read(transcriptionProvider);

        if (transcriptionState.engine == TranscriptionEngine.whisper) {
          debugPrint('[AudioNotifier] Using Whisper (Offline)');
          final locale = _ref.read(localeProvider);
          transcription = await _whisperService.transcribe(
            path,
            language: locale.languageCode,
          );
        } else {
          debugPrint('[AudioNotifier] Using Gemini (Online)');
          transcription = await _geminiService.transcribeAudio(path);
        }
      } catch (e) {
        debugPrint('[AudioNotifier] Transcription error: $e');
      }

      debugPrint('[AudioNotifier] Transcription result: $transcription');

      state = state.copyWith(
        isTranscribing: false,
        lastTranscription: transcription,
      );
    } else {
      state = state.copyWith(
        recordingState: AudioRecordingState.idle,
        errorMessage: 'Failed to save recording.',
      );
    }
  }

  /// Toggle recording
  Future<void> toggleRecording() async {
    debugPrint(
      '[AudioNotifier] Toggle recording. Current state: ${state.recordingState}',
    );
    if (state.isRecording) {
      await stopRecording();
    } else {
      await startRecording();
    }
  }

  /// Play audio
  Future<void> play() async {
    if (state.audioPath == null) return;

    if (state.playbackState == AudioPlaybackState.completed) {
      await _audioService.seekTo(Duration.zero);
    }

    state = state.copyWith(playbackState: AudioPlaybackState.playing);
    await _audioService.playAudio();
  }

  /// Pause audio
  Future<void> pause() async {
    state = state.copyWith(playbackState: AudioPlaybackState.paused);
    await _audioService.pauseAudio();
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// Seek to position
  Future<void> seekTo(Duration position) async {
    await _audioService.seekTo(position);
    state = state.copyWith(playbackPosition: position);
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    await _audioService.setSpeed(speed);
    state = state.copyWith(playbackSpeed: speed);
  }

  /// Cycle through playback speeds
  Future<void> cycleSpeed() async {
    final speeds = [0.5, 1.0, 1.5, 2.0];
    final currentIndex = speeds.indexOf(state.playbackSpeed);
    final nextIndex = (currentIndex + 1) % speeds.length;
    await setSpeed(speeds[nextIndex]);
  }

  /// Skip forward 10 seconds
  Future<void> skipForward() async {
    await _audioService.skipForward(const Duration(seconds: 10));
  }

  /// Skip backward 10 seconds
  Future<void> skipBackward() async {
    await _audioService.skipBackward(const Duration(seconds: 10));
  }

  /// Toggle segments popup visibility
  void toggleSegmentsPopup() {
    state = state.copyWith(
      isSegmentsPopupVisible: !state.isSegmentsPopupVisible,
      clearEditingSegment: true, // Exit edit mode when toggling popup
    );
  }

  /// Show segments popup
  void showSegmentsPopup() {
    state = state.copyWith(isSegmentsPopupVisible: true);
  }

  /// Hide segments popup
  void hideSegmentsPopup() {
    state = state.copyWith(
      isSegmentsPopupVisible: false,
      clearEditingSegment: true,
    );
  }

  /// Toggle player expansion
  void togglePlayerExpansion() {
    state = state.copyWith(isPlayerExpanded: !state.isPlayerExpanded);
  }

  /// Seek to specific segment
  Future<void> seekToSegment(int index) async {
    if (index < 0 || index >= state.segments.length) return;

    // Use seekToIndex for proper playlist navigation
    await _audioService.seekToIndex(index);
    state = state.copyWith(
      playbackPosition: state.segments[index].startPosition,
      currentSegmentIndex: index,
    );
  }

  /// Rename a segment
  void renameSegment(int index, String newName) {
    if (index < 0 || index >= state.segments.length) return;
    if (newName.trim().isEmpty) return;

    final updatedSegments = List<AudioSegment>.from(state.segments);
    updatedSegments[index] = updatedSegments[index].copyWith(
      name: newName.trim(),
    );

    state = state.copyWith(segments: updatedSegments);
  }

  /// Delete a segment
  Future<void> deleteSegment(int index) async {
    if (index < 0 || index >= state.segments.length) return;

    final updatedSegments = List<AudioSegment>.from(state.segments);
    final deletedSegment = updatedSegments.removeAt(index);
    final wasPlayingDeletedSegment = index == state.currentSegmentIndex;

    // Recalculate start positions for subsequent segments
    Duration cumulative = Duration.zero;
    for (int i = 0; i < updatedSegments.length; i++) {
      updatedSegments[i] = updatedSegments[i].copyWith(
        startPosition: cumulative,
      );
      cumulative += updatedSegments[i].duration;
    }

    // Attempt to delete the physical file
    try {
      final file = File(deletedSegment.filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[AudioNotifier] Deleted file: ${deletedSegment.filePath}');
      }
    } catch (e) {
      debugPrint('[AudioNotifier] Error deleting file: $e');
      // Continue anyway as we removed it from the list
    }

    // Prepare updated state
    final newTotalDuration = cumulative;
    final newAudioPath = updatedSegments.isEmpty ? null : state.audioPath;
    final newSegmentsCount = updatedSegments.length;

    // Stop playback if we deleted the active segment or list is empty
    if (updatedSegments.isEmpty) {
      await _audioService.stopAudio();
      state = state.copyWith(
        segments: [],
        recordingState: AudioRecordingState.idle,
        clearAudioPath: true, // Explicitly clear path
        playbackState: AudioPlaybackState.idle,
        playbackTotalDuration: Duration.zero,
        playbackPosition: Duration.zero,
        currentSegmentIndex: 0,
        errorMessage: null,
      );
      // Delete metadata file if it exists
      if (state.audioPath?.endsWith('.json') == true) {
        try {
          final file = File(state.audioPath!);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      return;
    }

    // Update state mid-way
    state = state.copyWith(
      segments: updatedSegments,
      playbackTotalDuration: newTotalDuration,
      audioPath: newAudioPath,
    );

    // Save metadata
    await _saveSegmentsMetadata();

    // Reload playlist
    final paths = updatedSegments.map((s) => s.filePath).toList();
    await _audioService.loadPlaylist(paths);

    // If we deleted the playing segment, or one before it, adjust
    if (wasPlayingDeletedSegment) {
      // Just stop or play next? Let's stop to be safe.
      await _audioService.stopAudio();
    } else if (state.currentSegmentIndex > index) {
      // Shift index down
      state = state.copyWith(
        currentSegmentIndex: state.currentSegmentIndex - 1,
      );
    }
  }

  /// Set which segment is being edited (for rename mode)
  void setEditingSegment(int? index) {
    state = state.copyWith(
      editingSegmentIndex: index,
      clearEditingSegment: index == null,
    );
  }

  /// Get segment index at a given playback position
  int? getSegmentAtPosition(Duration position) {
    Duration cumulative = Duration.zero;
    for (int i = 0; i < state.segments.length; i++) {
      cumulative += state.segments[i].duration;
      if (position < cumulative) {
        return i;
      }
    }
    return state.segments.isNotEmpty ? state.segments.length - 1 : null;
  }

  /// Clear last transcription
  void clearLastTranscription() {
    state = state.copyWith(clearLastTranscription: true);
  }

  /// Reset state
  void reset() {
    _audioService.stopAudio();
    state = const AudioState();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  @override
  void dispose() {
    _recordingDurationSub?.cancel();
    _playbackPositionSub?.cancel();
    _playbackDurationSub?.cancel();
    _amplitudeSub?.cancel();
    _playerStateSub?.cancel();
    _currentIndexSub?.cancel();
    _audioService.dispose();
    super.dispose();
  }
}

/// Provider for AudioService
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for BackendGeminiService
final backendGeminiServiceProvider = Provider<BackendGeminiService>((ref) {
  final authService = AuthService();
  final apiService = ApiService(authService: authService);
  return BackendGeminiService(apiService: apiService);
});

/// Provider for AudioNotifier
final audioProvider = StateNotifierProvider<AudioNotifier, AudioState>((ref) {
  final audioService = ref.watch(audioServiceProvider);
  final geminiService = ref.watch(backendGeminiServiceProvider);
  final whisperService = ref.watch(whisperServiceProvider);
  return AudioNotifier(ref, audioService, geminiService, whisperService);
});
