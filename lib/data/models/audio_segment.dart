/// Represents an individual audio recording segment within a diary entry
class AudioSegment {
  final String id;
  String name; // e.g., "Voice 001", "Voice 002"
  final String filePath;
  final Duration duration;
  final DateTime recordedAt;
  final Duration startPosition; // Position in combined audio timeline

  AudioSegment({
    required this.id,
    required this.name,
    required this.filePath,
    required this.duration,
    required this.recordedAt,
    required this.startPosition,
  });

  /// Creates a copy with optional updated fields
  AudioSegment copyWith({
    String? id,
    String? name,
    String? filePath,
    Duration? duration,
    DateTime? recordedAt,
    Duration? startPosition,
  }) {
    return AudioSegment(
      id: id ?? this.id,
      name: name ?? this.name,
      filePath: filePath ?? this.filePath,
      duration: duration ?? this.duration,
      recordedAt: recordedAt ?? this.recordedAt,
      startPosition: startPosition ?? this.startPosition,
    );
  }

  /// Format duration as HH:MM:SS or MM:SS
  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '0:$minutes:$seconds';
  }

  /// Format recorded date as MM/DD, HH:mm
  String get formattedDate {
    final month = recordedAt.month.toString().padLeft(2, '0');
    final day = recordedAt.day.toString().padLeft(2, '0');
    final hour = recordedAt.hour.toString().padLeft(2, '0');
    final minute = recordedAt.minute.toString().padLeft(2, '0');
    return '$month/$day, $hour:$minute';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'filePath': filePath,
      'durationMilliseconds': duration.inMilliseconds,
      'recordedAtIso': recordedAt.toIso8601String(),
      'startPositionMilliseconds': startPosition.inMilliseconds,
    };
  }

  factory AudioSegment.fromJson(Map<String, dynamic> json) {
    return AudioSegment(
      id: json['id'] as String,
      name: json['name'] as String,
      filePath: json['filePath'] as String,
      duration: Duration(milliseconds: json['durationMilliseconds'] as int),
      recordedAt: DateTime.parse(json['recordedAtIso'] as String),
      startPosition: Duration(
        milliseconds: json['startPositionMilliseconds'] as int,
      ),
    );
  }
}
