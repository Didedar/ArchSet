import 'dart:convert';

import 'package:equatable/equatable.dart';

/// A photographed artifact, assembled from an `ImageMetadata` row plus the
/// title of the note it was taken in.
///
/// The Gemini analysis is stored as a raw JSON string in the database; this
/// model owns decoding it so the UI never parses JSON itself.
///
/// Value equality keeps BLoC from re-emitting identical map state on every
/// unrelated database write.
class Artifact extends Equatable {
  final String id;
  final String imagePath;
  final double? latitude;
  final double? longitude;
  final DateTime capturedAt;
  final String? noteId;
  final String? noteTitle;
  final int commentCount;

  /// Decoded Gemini analysis, or null when the photo was never analyzed
  /// (or the stored JSON was unreadable).
  final Map<String, dynamic>? analysis;

  const Artifact({
    required this.id,
    required this.imagePath,
    required this.capturedAt,
    this.latitude,
    this.longitude,
    this.noteId,
    this.noteTitle,
    this.commentCount = 0,
    this.analysis,
  });

  /// Only artifacts with both coordinates can be placed on the map.
  bool get hasLocation => latitude != null && longitude != null;

  bool get isAnalyzed => analysis != null;

  Map<String, dynamic>? get spatialContext => _section('spatial_context');
  Map<String, dynamic>? get physicalCharacteristics =>
      _section('physical_characteristics');
  Map<String, dynamic>? get relationalContext => _section('relational_context');
  Map<String, dynamic>? get administrativeData =>
      _section('administrative_data');

  /// Short label for a map pin and the detail sheet header.
  ///
  /// Prefers what the object actually is, then what it's made of, then the
  /// note it came from. Gemini fills unresolved fields with "unknown" (and
  /// its Russian equivalents), which is no more useful than a fallback.
  String? get displayTitle {
    final physical = physicalCharacteristics;
    final candidates = <Object?>[
      physical?['object_type'],
      physical?['material'],
      administrativeData?['unique_code'],
      noteTitle,
    ];
    for (final candidate in candidates) {
      final value = _meaningful(candidate);
      if (value != null) return value;
    }
    return null;
  }

  Map<String, dynamic>? _section(String key) {
    final value = analysis?[key];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  /// Treats blanks and Gemini's placeholder values as "no answer".
  static String? _meaningful(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    const placeholders = {
      'unknown',
      'n/a',
      'null',
      'неизвестно',
      'не известно',
      'нет данных',
      'не определено',
    };
    if (placeholders.contains(text.toLowerCase())) return null;
    return text;
  }

  @override
  List<Object?> get props => [
    id,
    imagePath,
    latitude,
    longitude,
    capturedAt,
    noteId,
    noteTitle,
    commentCount,
    analysis,
  ];

  /// Decodes an `analysisResult` column value, tolerating malformed JSON and
  /// non-object payloads rather than throwing into a stream.
  static Map<String, dynamic>? decodeAnalysis(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } on FormatException {
      return null;
    }
  }
}

/// A user comment attached to an [Artifact].
class ArtifactComment extends Equatable {
  final String id;
  final String artifactId;
  final String body;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ArtifactComment({
    required this.id,
    required this.artifactId,
    required this.body,
    required this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [id, artifactId, body, createdAt, updatedAt];
}
