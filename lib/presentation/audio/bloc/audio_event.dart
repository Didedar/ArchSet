part of 'audio_bloc.dart';

sealed class AudioEvent {
  const AudioEvent();
}

/// Loads existing audio for the note being edited: a single file, or a
/// `.json` segments-metadata file written by a prior recording session.
final class AudioInitRequested extends AudioEvent {
  const AudioInitRequested(this.path);

  final String? path;
}

/// Starts recording if idle, or stops (and transcribes) if recording.
/// [engine]/[languageCode] come from TranscriptionBloc/LocaleBloc state,
/// read by the widget at dispatch time -- AudioBloc never reads another
/// BLoC's state directly.
final class AudioRecordingToggleRequested extends AudioEvent {
  const AudioRecordingToggleRequested({
    required this.engine,
    required this.languageCode,
  });

  final TranscriptionEngine engine;
  final String languageCode;
}

final class AudioPlayRequested extends AudioEvent {
  const AudioPlayRequested();
}

final class AudioPlayPauseToggled extends AudioEvent {
  const AudioPlayPauseToggled();
}

final class AudioSeekRequested extends AudioEvent {
  const AudioSeekRequested(this.position);

  final Duration position;
}

final class AudioSpeedCycleRequested extends AudioEvent {
  const AudioSpeedCycleRequested();
}

final class AudioSkipForwardRequested extends AudioEvent {
  const AudioSkipForwardRequested();
}

final class AudioSkipBackwardRequested extends AudioEvent {
  const AudioSkipBackwardRequested();
}

final class AudioSegmentsPopupShown extends AudioEvent {
  const AudioSegmentsPopupShown();
}

final class AudioSegmentsPopupHidden extends AudioEvent {
  const AudioSegmentsPopupHidden();
}

final class AudioPlayerExpansionToggled extends AudioEvent {
  const AudioPlayerExpansionToggled();
}

final class AudioSegmentSeekRequested extends AudioEvent {
  const AudioSegmentSeekRequested(this.index);

  final int index;
}

final class AudioSegmentRenamed extends AudioEvent {
  const AudioSegmentRenamed(this.index, this.name);

  final int index;
  final String name;
}

final class AudioSegmentDeleted extends AudioEvent {
  const AudioSegmentDeleted(this.index);

  final int index;
}

final class AudioLastTranscriptionCleared extends AudioEvent {
  const AudioLastTranscriptionCleared();
}

final class AudioReset extends AudioEvent {
  const AudioReset();
}

final class _RecordingDurationUpdated extends AudioEvent {
  const _RecordingDurationUpdated(this.duration);

  final Duration duration;
}

final class _PlaybackPositionUpdated extends AudioEvent {
  const _PlaybackPositionUpdated(this.position);

  final Duration position;
}

final class _PlaybackDurationUpdated extends AudioEvent {
  const _PlaybackDurationUpdated(this.duration);

  final Duration duration;
}

final class _AmplitudesUpdated extends AudioEvent {
  const _AmplitudesUpdated(this.amplitudes);

  final List<double> amplitudes;
}

final class _PlayerStateUpdated extends AudioEvent {
  const _PlayerStateUpdated(this.playerState);

  final PlayerState playerState;
}

final class _CurrentIndexUpdated extends AudioEvent {
  const _CurrentIndexUpdated(this.index);

  final int? index;
}
