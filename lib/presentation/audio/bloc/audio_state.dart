part of 'audio_bloc.dart';

enum AudioRecordingState { idle, recording, recorded }

enum AudioPlaybackState { idle, loading, playing, paused, completed }

final class AudioState extends Equatable {
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
    this.segmentCounter = 0,
    this.isPlayerExpanded = true,
    this.currentSegmentIndex = 0,
    this.isTranscribing = false,
    this.lastTranscription,
  });

  final AudioRecordingState recordingState;
  final AudioPlaybackState playbackState;
  final Duration recordingDuration;
  final Duration playbackPosition;
  final Duration playbackTotalDuration;
  final String? audioPath;
  final List<double> amplitudes;
  final double playbackSpeed;
  final String? errorMessage;
  final List<AudioSegment> segments;
  final bool isSegmentsPopupVisible;
  final int segmentCounter;
  final bool isPlayerExpanded;
  final int currentSegmentIndex;
  final bool isTranscribing;
  final String? lastTranscription;

  bool get isRecording => recordingState == AudioRecordingState.recording;
  bool get hasRecording =>
      recordingState == AudioRecordingState.recorded || audioPath != null;
  bool get isPlaying => playbackState == AudioPlaybackState.playing;

  /// Index of the currently playing segment; falls back to 0 when
  /// [currentSegmentIndex] is out of range, -1 when there are no segments.
  int get activeSegmentIndex {
    if (segments.isEmpty) return -1;
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
    bool clearAudioPath = false,
    List<double>? amplitudes,
    double? playbackSpeed,
    // Unlike every other field, errorMessage does NOT fall back to the
    // previous value: any copyWith that doesn't explicitly pass it clears
    // it. This matches the original AudioNotifier design so that a
    // transient error doesn't linger through subsequent state updates.
    String? errorMessage,
    List<AudioSegment>? segments,
    bool? isSegmentsPopupVisible,
    int? segmentCounter,
    bool? isPlayerExpanded,
    int? currentSegmentIndex,
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
      segmentCounter: segmentCounter ?? this.segmentCounter,
      isPlayerExpanded: isPlayerExpanded ?? this.isPlayerExpanded,
      currentSegmentIndex: currentSegmentIndex ?? this.currentSegmentIndex,
      isTranscribing: isTranscribing ?? this.isTranscribing,
      lastTranscription: clearLastTranscription
          ? null
          : (lastTranscription ?? this.lastTranscription),
    );
  }

  @override
  List<Object?> get props => [
        recordingState,
        playbackState,
        recordingDuration,
        playbackPosition,
        playbackTotalDuration,
        audioPath,
        amplitudes,
        playbackSpeed,
        errorMessage,
        segments,
        isSegmentsPopupVisible,
        segmentCounter,
        isPlayerExpanded,
        currentSegmentIndex,
        isTranscribing,
        lastTranscription,
      ];
}
