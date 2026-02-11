import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/localization/app_strings.dart';
import '../../data/models/audio_segment.dart';

/// Model class for a transcription segment with timing
class TranscriptionSegment {
  final String id;
  final String text;
  final Duration startTime; // Time within the segment (starts from 0)
  final Duration endTime;
  final String audioName;
  final String filePath;
  final Duration duration;

  const TranscriptionSegment({
    required this.id,
    required this.text,
    required this.startTime,
    required this.endTime,
    required this.audioName,
    required this.filePath,
    required this.duration,
  });

  /// Format duration as MM:SS
  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get formattedTimeRange =>
      '${formatDuration(startTime)} - ${formatDuration(endTime)}';

  /// Factory to create TranscriptionSegments from AudioSegments with transcription text
  /// Each audio segment starts from 0:00
  static List<TranscriptionSegment> fromAudioSegments({
    required List<AudioSegment> audioSegments,
    required String transcriptionText,
  }) {
    if (audioSegments.isEmpty) return [];

    final segments = <TranscriptionSegment>[];
    final words = transcriptionText.split(RegExp(r'\s+'));

    // Calculate total duration
    final totalDuration = audioSegments.fold<Duration>(
      Duration.zero,
      (sum, seg) => sum + seg.duration,
    );

    // Distribute words proportionally across segments based on their duration
    int wordIndex = 0;
    for (int i = 0; i < audioSegments.length; i++) {
      final audioSeg = audioSegments[i];

      // Calculate how many words this segment should get
      String segmentText = '';
      if (words.isNotEmpty && transcriptionText.isNotEmpty) {
        final durationRatio =
            audioSeg.duration.inMilliseconds / totalDuration.inMilliseconds;
        final wordsForSegment = (words.length * durationRatio).round();

        // Get words for this segment
        final endWordIndex = (wordIndex + wordsForSegment).clamp(
          0,
          words.length,
        );
        final segmentWords = words.sublist(wordIndex, endWordIndex);
        wordIndex = endWordIndex;
        segmentText = segmentWords.join(' ');
      }

      // Each segment's time starts from 0
      segments.add(
        TranscriptionSegment(
          id: audioSeg.id,
          text: segmentText,
          startTime: Duration.zero, // Always starts from 0
          endTime: audioSeg.duration, // Ends at segment duration
          audioName: audioSeg.name,
          filePath: audioSeg.filePath,
          duration: audioSeg.duration,
        ),
      );
    }

    // If there are remaining words, add them to the last segment
    if (wordIndex < words.length && segments.isNotEmpty) {
      final lastSegment = segments.removeLast();
      final remainingWords = words.sublist(wordIndex);
      segments.add(
        TranscriptionSegment(
          id: lastSegment.id,
          text: '${lastSegment.text} ${remainingWords.join(' ')}'.trim(),
          startTime: lastSegment.startTime,
          endTime: lastSegment.endTime,
          audioName: lastSegment.audioName,
          filePath: lastSegment.filePath,
          duration: lastSegment.duration,
        ),
      );
    }

    return segments;
  }
}

/// TranscriptionPage displays the full audio transcription with tabs for each audio
class TranscriptionPage extends ConsumerStatefulWidget {
  /// Audio file paths for playlist playback
  final List<String>? audioPaths;

  /// Pre-created segments (if available)
  final List<TranscriptionSegment>? segments;

  /// Real audio segments from audioProvider
  final List<AudioSegment>? audioSegments;

  /// Raw text and duration (alternative to segments)
  final String? transcriptionText;
  final Duration? audioDuration;
  final String audioName;

  /// Words with timings in JSON format (alternative to segments)
  final List<Map<String, dynamic>>? wordsWithTimings;

  const TranscriptionPage({
    super.key,
    this.audioPaths,
    this.segments,
    this.audioSegments,
    this.transcriptionText,
    this.audioDuration,
    this.audioName = 'Audio - 001',
    this.wordsWithTimings,
  });

  @override
  ConsumerState<TranscriptionPage> createState() => _TranscriptionPageState();
}

class _TranscriptionPageState extends ConsumerState<TranscriptionPage>
    with SingleTickerProviderStateMixin {
  late List<TranscriptionSegment> _segments;
  late TabController _tabController;
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeSegments();
    _tabController = TabController(
      length: _segments.isNotEmpty ? _segments.length : 1,
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);
    _initializeAudio();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentTabIndex = _tabController.index;
        _currentPosition = Duration.zero;
      });
      _loadAudioForTab(_tabController.index);
    }
  }

  void _initializeSegments() {
    if (widget.segments != null) {
      _segments = widget.segments!;
    } else if (widget.audioSegments != null &&
        widget.audioSegments!.isNotEmpty) {
      _segments = TranscriptionSegment.fromAudioSegments(
        audioSegments: widget.audioSegments!,
        transcriptionText: widget.transcriptionText ?? '',
      );
    } else if (widget.audioPaths != null && widget.audioPaths!.isNotEmpty) {
      // Create segments from audio paths only
      _segments = widget.audioPaths!.asMap().entries.map((entry) {
        final index = entry.key;
        final path = entry.value;
        return TranscriptionSegment(
          id: 'segment_$index',
          text: widget.transcriptionText ?? '',
          startTime: Duration.zero,
          endTime: widget.audioDuration ?? Duration.zero,
          audioName: 'Voice ${(index + 1).toString().padLeft(3, '0')}',
          filePath: path,
          duration: widget.audioDuration ?? Duration.zero,
        );
      }).toList();
    } else {
      _segments = [];
    }
  }

  Future<void> _initializeAudio() async {
    await _loadAudioForTab(0);
  }

  Future<void> _loadAudioForTab(int index) async {
    if (_segments.isEmpty || index >= _segments.length) return;

    final segment = _segments[index];

    // Dispose previous player
    await _audioPlayer?.dispose();
    _audioPlayer = AudioPlayer();

    try {
      await _audioPlayer!.setFilePath(segment.filePath);

      // Listen to player state changes
      _audioPlayer!.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
          });
        }
      });

      // Listen to position updates
      _audioPlayer!.positionStream.listen((position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
        }
      });

      // Listen to duration updates
      _audioPlayer!.durationStream.listen((duration) {
        if (mounted && duration != null && _segments.isNotEmpty) {
          // Update segment duration if needed
          final currentSegment = _segments[_currentTabIndex];
          if (currentSegment.duration == Duration.zero) {
            setState(() {
              _segments[_currentTabIndex] = TranscriptionSegment(
                id: currentSegment.id,
                text: currentSegment.text,
                startTime: Duration.zero,
                endTime: duration,
                audioName: currentSegment.audioName,
                filePath: currentSegment.filePath,
                duration: duration,
              );
            });
          }
        }
      });
    } catch (e) {
      debugPrint('Error loading audio: $e');
    }
  }

  Future<void> _togglePlayPause() async {
    if (_audioPlayer == null) return;

    if (_isPlaying) {
      await _audioPlayer!.pause();
    } else {
      await _audioPlayer!.play();
    }
  }

  Future<void> _seekTo(Duration position) async {
    await _audioPlayer?.seek(position);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: textColor, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppStrings.tr(ref, AppStrings.transcription),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: textColor,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: textColor, size: 24),
            onPressed: () {
              _showOptionsMenu(context);
            },
          ),
        ],
        bottom: _segments.length > 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: _buildTabBar(),
              )
            : null,
      ),
      body: _segments.isEmpty ? _buildEmptyState() : _buildContent(),
    );
  }

  Widget _buildTabBar() {
    final theme = Theme.of(context);
    // Use cardColor or similar for tab bar background
    final tabBarBg = theme.cardColor;

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: tabBarBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicator: BoxDecoration(
          color:
              theme.colorScheme.primary, // Using primary color for active tab
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: theme.colorScheme.onPrimary,
        unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
        labelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: _segments.map((segment) {
          return Tab(text: segment.audioName);
        }).toList(),
      ),
    );
  }

  Widget _buildContent() {
    if (_segments.length == 1) {
      // Single audio - no tabs needed
      return _buildSegmentContent(_segments.first);
    }

    return TabBarView(
      controller: _tabController,
      children: _segments.map((segment) {
        return _buildSegmentContent(segment);
      }).toList(),
    );
  }

  Widget _buildSegmentContent(TranscriptionSegment segment) {
    return Column(
      children: [
        // Audio player controls
        _buildAudioPlayer(segment),
        const SizedBox(height: 16),
        // Transcription content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _TranscriptionSegmentCard(
              segment: segment,
              currentPosition: _currentPosition,
              onTimeStampTap: () => _seekTo(Duration.zero),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioPlayer(TranscriptionSegment segment) {
    final duration = segment.duration;
    final position = _currentPosition;
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final textColor = theme.colorScheme.onSurface;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Audio name and duration
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                segment.audioName,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
              Text(
                '${TranscriptionSegment.formatDuration(position)} / ${TranscriptionSegment.formatDuration(duration)}',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: textColor.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor: theme.colorScheme.onSurface.withOpacity(0.2),
              thumbColor: theme.colorScheme.primary,
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: duration.inMilliseconds > 0
                  ? (position.inMilliseconds / duration.inMilliseconds).clamp(
                      0.0,
                      1.0,
                    )
                  : 0.0,
              onChanged: (value) {
                final newPosition = Duration(
                  milliseconds: (duration.inMilliseconds * value).toInt(),
                );
                _seekTo(newPosition);
              },
            ),
          ),
          const SizedBox(height: 8),
          // Play/pause button
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: theme.colorScheme.primary,
              size: 56,
            ),
            onPressed: _togglePlayPause,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.transcribe_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.tr(ref, AppStrings.noTranscriptionAvailable),
            style: GoogleFonts.inter(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.copy, color: theme.colorScheme.onSurface),
              title: Text(
                AppStrings.tr(ref, AppStrings.copyTranscription),
                style: GoogleFonts.inter(color: theme.colorScheme.onSurface),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement copy functionality
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: theme.colorScheme.onSurface),
              title: Text(
                AppStrings.tr(ref, AppStrings.share),
                style: GoogleFonts.inter(color: theme.colorScheme.onSurface),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement share functionality
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual transcription segment card widget
class _TranscriptionSegmentCard extends ConsumerWidget {
  final TranscriptionSegment segment;
  final Duration currentPosition;
  final VoidCallback onTimeStampTap;

  const _TranscriptionSegmentCard({
    required this.segment,
    required this.currentPosition,
    required this.onTimeStampTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isActive =
        currentPosition >= segment.startTime &&
        currentPosition < segment.endTime;
    final primaryColor = theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(color: primaryColor.withOpacity(0.5), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with timestamp and audio name
          Row(
            children: [
              // Timestamp (tappable)
              GestureDetector(
                onTap: onTimeStampTap,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time, size: 14, color: primaryColor),
                    const SizedBox(width: 6),
                    Text(
                      // Show time from 0:00 to segment duration
                      '00:00 - ${TranscriptionSegment.formatDuration(segment.duration)}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Audio name
              Text(
                segment.audioName,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w400,
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Transcription text
          if (segment.text.isNotEmpty)
            Text(
              segment.text,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w400,
                fontSize: 15,
                color: theme.colorScheme.onSurface,
                height: 1.5,
              ),
            )
          else
            Text(
              AppStrings.tr(ref, AppStrings.noTranscriptionTextAvailable),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w400,
                fontSize: 15,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }
}
