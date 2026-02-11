/// Audio service for recording and playback.
///
/// Handles local audio recording using device microphone and playback.
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/audio_segment.dart';

/// Service for handling audio recording and playback
class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final List<AudioSegment> _segments = [];
  final List<double> _amplitudes = [];

  bool _isRecording = false;
  bool _isPlaying = false;
  DateTime? _recordingStartTime;
  Timer? _durationTimer;
  Timer? _amplitudeTimer;
  Duration _currentRecordingDuration = Duration.zero;

  // Stream controllers
  final StreamController<bool> _recordingStateController =
      StreamController.broadcast();
  final StreamController<bool> _playingStateController =
      StreamController.broadcast();
  final StreamController<Duration> _recordingDurationController =
      StreamController.broadcast();
  final StreamController<Duration> _playbackPositionController =
      StreamController.broadcast();
  final StreamController<Duration> _playbackDurationController =
      StreamController.broadcast();
  final StreamController<List<AudioSegment>> _segmentsController =
      StreamController.broadcast();
  final StreamController<List<double>> _amplitudeController =
      StreamController.broadcast();
  final StreamController<int?> _currentIndexController =
      StreamController.broadcast();

  // Getters
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  List<AudioSegment> get segments => List.unmodifiable(_segments);
  Duration get currentRecordingDuration => _currentRecordingDuration;
  Duration? get totalDuration => _player.duration;
  List<double> get amplitudes => List.unmodifiable(_amplitudes);

  // Streams
  Stream<bool> get recordingStateStream => _recordingStateController.stream;
  Stream<bool> get playingStateStream => _playingStateController.stream;
  Stream<Duration> get recordingDurationStream =>
      _recordingDurationController.stream;
  Stream<Duration> get playbackPositionStream => _player.positionStream;
  Stream<Duration> get playbackDurationStream =>
      _playbackDurationController.stream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<List<AudioSegment>> get segmentsStream => _segmentsController.stream;
  Stream<List<double>> get amplitudeStream => _amplitudeController.stream;
  Stream<int?> get currentIndexStream => _currentIndexController.stream;

  AudioService() {
    _player.durationStream.listen((duration) {
      if (duration != null) {
        _playbackDurationController.add(duration);
      }
    });

    _player.currentIndexStream.listen((index) {
      _currentIndexController.add(index);
    });

    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _isPlaying = false;
        _playingStateController.add(false);
      }
    });
  }

  /// Request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Start recording audio
  Future<bool> startRecording() async {
    if (_isRecording) return false;

    final hasPermission = await requestPermission();
    if (!hasPermission) {
      debugPrint('[AudioService] Microphone permission denied');
      return false;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${directory.path}/audio');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      final fileName = '${const Uuid().v4()}.m4a';
      final filePath = '${audioDir.path}/$fileName';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      _isRecording = true;
      _recordingStartTime = DateTime.now();
      _currentRecordingDuration = Duration.zero;
      _amplitudes.clear();
      _recordingStateController.add(true);

      // Start duration timer
      _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (_recordingStartTime != null) {
          _currentRecordingDuration = DateTime.now().difference(
            _recordingStartTime!,
          );
          _recordingDurationController.add(_currentRecordingDuration);
        }
      });

      // Start amplitude polling
      _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (
        _,
      ) async {
        try {
          final amp = await _recorder.getAmplitude();
          // Normalize amplitude to 0-1 range
          final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
          _amplitudes.add(normalized);
          _amplitudeController.add(List.from(_amplitudes));
        } catch (_) {}
      });

      debugPrint('[AudioService] Started recording to: $filePath');
      return true;
    } catch (e) {
      debugPrint('[AudioService] Failed to start recording: $e');
      return false;
    }
  }

  /// Stop recording and return path
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      final path = await _recorder.stop();
      _durationTimer?.cancel();
      _amplitudeTimer?.cancel();
      _isRecording = false;
      _recordingStateController.add(false);

      debugPrint('[AudioService] Stopped recording: $path');
      return path;
    } catch (e) {
      debugPrint('[AudioService] Failed to stop recording: $e');
      _isRecording = false;
      _recordingStateController.add(false);
      return null;
    }
  }

  /// Load single audio file
  Future<void> loadAudio(String path) async {
    try {
      await _player.setFilePath(path);
    } catch (e) {
      debugPrint('[AudioService] Failed to load audio: $e');
    }
  }

  /// Load multiple audio files as playlist
  Future<void> loadPlaylist(List<String> paths) async {
    if (paths.isEmpty) return;

    try {
      final playlist = ConcatenatingAudioSource(
        children: paths.map((path) => AudioSource.file(path)).toList(),
      );
      await _player.setAudioSource(playlist);
    } catch (e) {
      debugPrint('[AudioService] Failed to load playlist: $e');
    }
  }

  /// Play audio
  Future<void> playAudio() async {
    try {
      _isPlaying = true;
      _playingStateController.add(true);
      await _player.play();
    } catch (e) {
      debugPrint('[AudioService] Failed to play: $e');
      _isPlaying = false;
      _playingStateController.add(false);
    }
  }

  /// Play a specific segment
  Future<void> playSegment(AudioSegment segment) async {
    await loadAudio(segment.filePath);
    await playAudio();
  }

  /// Pause playback
  Future<void> pauseAudio() async {
    await _player.pause();
    _isPlaying = false;
    _playingStateController.add(false);
  }

  /// Stop playback
  Future<void> stopAudio() async {
    await _player.stop();
    _isPlaying = false;
    _playingStateController.add(false);
  }

  /// Seek to position
  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  /// Seek to specific index in playlist
  Future<void> seekToIndex(
    int index, {
    Duration position = Duration.zero,
  }) async {
    await _player.seek(position, index: index);
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  /// Skip forward by duration
  Future<void> skipForward(Duration duration) async {
    final current = _player.position;
    final total = _player.duration ?? Duration.zero;
    final newPosition = current + duration;
    await _player.seek(newPosition > total ? total : newPosition);
  }

  /// Skip backward by duration
  Future<void> skipBackward(Duration duration) async {
    final current = _player.position;
    final newPosition = current - duration;
    await _player.seek(
      newPosition < Duration.zero ? Duration.zero : newPosition,
    );
  }

  /// Delete a segment
  Future<void> deleteSegment(String segmentId) async {
    final index = _segments.indexWhere((s) => s.id == segmentId);
    if (index != -1) {
      final segment = _segments[index];
      final file = File(segment.filePath);
      if (await file.exists()) {
        await file.delete();
      }
      _segments.removeAt(index);
      _segmentsController.add(List.from(_segments));
    }
  }

  /// Clear all segments
  Future<void> clearSegments() async {
    for (final segment in _segments) {
      final file = File(segment.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    _segments.clear();
    _segmentsController.add(List.from(_segments));
  }

  /// Load segments from paths (for restoring state)
  Future<void> loadSegments(List<AudioSegment> segments) async {
    _segments.clear();
    _segments.addAll(segments);
    _segmentsController.add(List.from(_segments));
  }

  /// Get combined audio path (for saving with note)
  String? get combinedAudioPath {
    if (_segments.isEmpty) return null;
    return _segments.map((s) => s.filePath).join(',');
  }

  /// Dispose resources
  void dispose() {
    _durationTimer?.cancel();
    _amplitudeTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
    _recordingStateController.close();
    _playingStateController.close();
    _recordingDurationController.close();
    _playbackDurationController.close();
    _segmentsController.close();
    _amplitudeController.close();
    _currentIndexController.close();
  }
}
