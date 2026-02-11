import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_provider.dart';
import 'audio_segments_popup.dart';

/// Audio player widget matching the design specifications
/// - Container: 352x84px, background #2c2c2e, border-radius 20px
/// - Waveform visualization with playback progress
/// - Playback controls: speed, rewind, play/pause, forward
class AudioPlayerWidget extends ConsumerStatefulWidget {
  const AudioPlayerWidget({super.key});

  @override
  ConsumerState<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends ConsumerState<AudioPlayerWidget> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    // Don't update state here as this might be called during dispose
  }

  void _togglePopup() {
    final audioNotifier = ref.read(audioProvider.notifier);

    if (_overlayEntry != null) {
      _removeOverlay();
      audioNotifier.hideSegmentsPopup();
      return;
    }

    // Update state to show popup
    audioNotifier.showSegmentsPopup();

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                _removeOverlay();
                audioNotifier.hideSegmentsPopup();
              },
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            width: 282,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(-250, -140), // Adjust to appear above left
              child: Material(
                color: Colors.transparent,
                child: AudioSegmentsPopup(
                  onClose: () {
                    _removeOverlay();
                    audioNotifier.hideSegmentsPopup();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioProvider);
    final audioNotifier = ref.read(audioProvider.notifier);

    // Respect expanded state
    if (!audioState.isPlayerExpanded) {
      return const SizedBox.shrink();
    }

    // Close overlay if state changes externally (e.g. hiding via other means)
    if (!audioState.isSegmentsPopupVisible && _overlayEntry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_overlayEntry != null) _removeOverlay();
      });
    }

    if (!audioState.hasRecording) {
      return const SizedBox.shrink();
    }

    final progress = audioState.playbackTotalDuration.inMilliseconds > 0
        ? audioState.playbackPosition.inMilliseconds /
              audioState.playbackTotalDuration.inMilliseconds
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 352,
          height: 84,
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2E),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top row: Time and waveform
              Row(
                children: [
                  // Current position
                  Text(
                    _formatDuration(audioState.playbackPosition),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Waveform visualization
                  Expanded(
                    child: GestureDetector(
                      onTapDown: (details) {
                        final box = context.findRenderObject() as RenderBox?;
                        if (box != null) {
                          final localPosition = details.localPosition;
                          // Account for padding and time labels
                          final waveformWidth =
                              box.size.width - 32 - 80; // padding + labels
                          final seekPercent = (localPosition.dx / waveformWidth)
                              .clamp(0.0, 1.0);
                          final seekPosition = Duration(
                            milliseconds:
                                (audioState
                                            .playbackTotalDuration
                                            .inMilliseconds *
                                        seekPercent)
                                    .toInt(),
                          );

                          // Find which segment this maps to and seek
                          audioNotifier.seekTo(seekPosition);
                        }
                      },
                      child: _WaveformVisualization(
                        amplitudes: audioState.amplitudes,
                        progress: progress,
                        segments: audioState.segments,
                        totalDuration: audioState.playbackTotalDuration,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Total duration
                  Text(
                    _formatDuration(audioState.playbackTotalDuration),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              // Bottom row: Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Speed button
                  GestureDetector(
                    onTap: () => audioNotifier.cycleSpeed(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${audioState.playbackSpeed}x',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Playback controls
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Rewind 10s
                      GestureDetector(
                        onTap: () => audioNotifier.skipBackward(),
                        child: const Icon(
                          Icons.replay_10,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Play/Pause
                      GestureDetector(
                        onTap: () => audioNotifier.togglePlayPause(),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            audioState.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: const Color(0xFF2C2C2E),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Forward 10s
                      GestureDetector(
                        onTap: () => audioNotifier.skipForward(),
                        child: const Icon(
                          Icons.forward_10,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  // Playlist/menu icon
                  CompositedTransformTarget(
                    link: _layerLink,
                    child: GestureDetector(
                      onTap: _togglePopup,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: audioState.isSegmentsPopupVisible
                              ? Colors.white.withOpacity(0.2)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.playlist_play,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (audioState.isTranscribing) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Transcribing ...',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Waveform visualization widget
class _WaveformVisualization extends StatelessWidget {
  final List<double> amplitudes;
  final double progress;
  final List<dynamic>
  segments; // Use dynamic to avoid import issues if possible, or dynamic cast
  final Duration totalDuration;

  const _WaveformVisualization({
    required this.amplitudes,
    required this.progress,
    required this.segments,
    required this.totalDuration,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 24),
      painter: _WaveformPainter(
        amplitudes: amplitudes,
        progress: progress,
        playedColor: Colors.white,
        unplayedColor: Colors.white.withValues(alpha: 0.3),
        segments: segments,
        totalDuration: totalDuration,
      ),
    );
  }
}

/// Custom painter for waveform
class _WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;
  final List<dynamic> segments;
  final Duration totalDuration;

  _WaveformPainter({
    required this.amplitudes,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
    required this.segments,
    required this.totalDuration,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) {
      // Draw placeholder waveform
      _drawPlaceholderWaveform(canvas, size);
      return;
    }

    final barWidth = 2.0;
    final gap = 2.0;
    final totalBarWidth = barWidth + gap;
    final barCount = (size.width / totalBarWidth).floor();

    // Resample amplitudes to match bar count
    final sampledAmplitudes = _resampleAmplitudes(amplitudes, barCount);

    final playedPaint = Paint()
      ..color = playedColor
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;

    final unplayedPaint = Paint()
      ..color = unplayedColor
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    final maxHeight = size.height * 0.8;

    for (int i = 0; i < sampledAmplitudes.length; i++) {
      final x = i * totalBarWidth + barWidth / 2;
      final amplitude = sampledAmplitudes[i];
      final height = (amplitude * maxHeight).clamp(4.0, maxHeight);

      final isPlayed = (i / sampledAmplitudes.length) <= progress;
      final paint = isPlayed ? playedPaint : unplayedPaint;

      canvas.drawLine(
        Offset(x, centerY - height / 2),
        Offset(x, centerY + height / 2),
        paint,
      );
    }

    // Draw segment markers
    if (segments.isNotEmpty && totalDuration.inMilliseconds > 0) {
      final markerPaint = Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      for (final segment in segments) {
        // Skip the first segment start (0.0)
        if (segment.startPosition == Duration.zero) continue;

        final segmentProgress =
            segment.startPosition.inMilliseconds / totalDuration.inMilliseconds;

        if (segmentProgress >= 0 && segmentProgress <= 1) {
          final x = segmentProgress * size.width;

          // Draw a vertical dash line
          final dashHeight = size.height * 0.6;
          final dashTop = (size.height - dashHeight) / 2;

          canvas.drawLine(
            Offset(x, dashTop),
            Offset(x, dashTop + dashHeight),
            markerPaint,
          );
        }
      }
    }
  }

  void _drawPlaceholderWaveform(Canvas canvas, Size size) {
    final barWidth = 2.0;
    final gap = 2.0;
    final totalBarWidth = barWidth + gap;
    final barCount = (size.width / totalBarWidth).floor();

    final paint = Paint()
      ..color = unplayedColor
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    final maxHeight = size.height * 0.6;

    for (int i = 0; i < barCount; i++) {
      final x = i * totalBarWidth + barWidth / 2;
      // Create a pseudo-random but consistent pattern
      final amplitude = 0.3 + 0.7 * ((i * 13 + 7) % 10) / 10;
      final height = (amplitude * maxHeight).clamp(4.0, maxHeight);

      canvas.drawLine(
        Offset(x, centerY - height / 2),
        Offset(x, centerY + height / 2),
        paint,
      );
    }
  }

  List<double> _resampleAmplitudes(List<double> original, int targetCount) {
    if (original.isEmpty) return List.filled(targetCount, 0.3);
    if (original.length == targetCount) return original;

    final result = <double>[];
    final ratio = original.length / targetCount;

    for (int i = 0; i < targetCount; i++) {
      final startIndex = (i * ratio).floor();
      final endIndex = ((i + 1) * ratio).floor().clamp(0, original.length);

      if (startIndex >= endIndex) {
        result.add(original[startIndex.clamp(0, original.length - 1)]);
      } else {
        double sum = 0;
        for (int j = startIndex; j < endIndex; j++) {
          sum += original[j];
        }
        result.add(sum / (endIndex - startIndex));
      }
    }

    return result;
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.amplitudes != amplitudes ||
        oldDelegate.progress != progress;
  }
}

class MiniAudioPlayer extends ConsumerWidget {
  const MiniAudioPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioNotifier = ref.read(audioProvider.notifier);
    final audioState = ref.watch(audioProvider);

    return GestureDetector(
      onTap: () {
        // Expand the full player
        audioNotifier.togglePlayerExpansion();
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          audioState.isPlaying ? Icons.pause : Icons.play_arrow,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          size: 20,
        ),
      ),
    );
  }
}
