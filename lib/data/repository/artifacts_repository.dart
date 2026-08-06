import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/artifact.dart' as models;

/// Reads photographed artifacts out of `ImageMetadata` and owns their comments.
///
/// Artifacts are never created here: rows are written by the diary editor when
/// a photo is inserted, and enriched with a Gemini analysis later. This
/// repository is the read side plus comment CRUD.
class ArtifactsRepository {
  final AppDatabase database;
  final Uuid _uuid;

  ArtifactsRepository(this.database, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  /// Artifacts that can be placed on the map, newest first.
  ///

  /// Restricts a query to one entry's finds, or to everything when [noteId]
  /// is null.
  ///
  /// Null means "no scope", never "photos with no entry": the map opened from
  /// the notes list shows the whole dig, and a caller that wants only loose
  /// photos would be asking a different question.
  Expression<bool> _scopedToNote(String? noteId) => noteId == null
      ? const Constant(true)
      : database.imageMetadata.noteId.equals(noteId);

  /// True when an artifact's parent entry is still alive.
  ///
  /// A photographed find only exists as part of the entry it was photographed
  /// in, so a pin without a live entry claims a find whose record is gone --
  /// someone would go looking for the context and find none.
  ///
  /// No exemption for a null `noteId`. Two earlier attempts carved one out,
  /// on the theory that a photo attached to nothing has nothing to outlive.
  /// The capture path disproves it: every photo is taken inside an entry and
  /// always records its id. A row with no note link is therefore not an
  /// unattached find but a leftover from before that column existed, whose
  /// entry is long gone -- and the exemption was keeping exactly those pins
  /// on the map with no way to remove them.
  Expression<bool> get _parentNoteAlive =>
      database.notes.isDeleted.equals(false);

  /// Joins note titles and comment counts in SQL so the map doesn't issue a
  /// query per pin.
  Stream<List<models.Artifact>> watchLocatedArtifacts({String? noteId}) {
    final commentCount = database.artifactComments.id.count();

    final query =
        database.select(database.imageMetadata).join([
            leftOuterJoin(
              database.notes,
              database.notes.id.equalsExp(database.imageMetadata.noteId),
            ),
            leftOuterJoin(
              database.artifactComments,
              database.artifactComments.artifactId.equalsExp(
                    database.imageMetadata.id,
                  ) &
                  database.artifactComments.isDeleted.equals(false),
            ),
          ])
          ..addColumns([commentCount])
          ..where(
            database.imageMetadata.isDeleted.equals(false) &
                _parentNoteAlive &
                _scopedToNote(noteId) &
                database.imageMetadata.latitude.isNotNull() &
                database.imageMetadata.longitude.isNotNull(),
          )
          ..groupBy([database.imageMetadata.id])
          ..orderBy([
            OrderingTerm(
              expression: database.imageMetadata.capturedAt,
              mode: OrderingMode.desc,
            ),
          ]);

    return query.watch().map(
      (rows) => rows.map((row) {
        final metadata = row.readTable(database.imageMetadata);
        // Left join: the note may be missing (noteId null, or note deleted).
        final note = row.readTableOrNull(database.notes);
        return _toArtifact(
          metadata,
          noteTitle: note?.isDeleted == true ? null : note?.title,
          commentCount: row.read(commentCount) ?? 0,
        );
      }).toList(),
    );
  }

  /// How many photos exist that the map cannot show because they have no GPS
  /// fix (permission denied, or an indoor timeout).
  Stream<int> watchUnlocatedCount({String? noteId}) {
    final count = database.imageMetadata.id.count();
    // Joined purely to reach `_parentNoteAlive`; the count itself is over
    // image_metadata, and the join is one-to-one on a primary key so it
    // cannot multiply rows.
    final query =
        database.selectOnly(database.imageMetadata).join([
            leftOuterJoin(
              database.notes,
              database.notes.id.equalsExp(database.imageMetadata.noteId),
            ),
          ])
          ..addColumns([count])
          ..where(
            database.imageMetadata.isDeleted.equals(false) &
                _parentNoteAlive &
                _scopedToNote(noteId) &
                (database.imageMetadata.latitude.isNull() |
                    database.imageMetadata.longitude.isNull()),
          );

    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  /// Photos without a GPS fix, newest first.
  Stream<List<models.Artifact>> watchUnlocatedArtifacts({String? noteId}) {
    final query =
        database.select(database.imageMetadata).join([
            leftOuterJoin(
              database.notes,
              database.notes.id.equalsExp(database.imageMetadata.noteId),
            ),
          ])
          ..where(
            database.imageMetadata.isDeleted.equals(false) &
                _parentNoteAlive &
                _scopedToNote(noteId) &
                (database.imageMetadata.latitude.isNull() |
                    database.imageMetadata.longitude.isNull()),
          )
          ..orderBy([
            OrderingTerm(
              expression: database.imageMetadata.capturedAt,
              mode: OrderingMode.desc,
            ),
          ]);

    return query.watch().map(
      (rows) => rows.map((row) {
        final metadata = row.readTable(database.imageMetadata);
        final note = row.readTableOrNull(database.notes);
        return _toArtifact(
          metadata,
          noteTitle: note?.isDeleted == true ? null : note?.title,
          commentCount: 0,
        );
      }).toList(),
    );
  }

  /// Comments on one artifact, oldest first so the sheet reads as a thread.
  Stream<List<models.ArtifactComment>> watchComments(String artifactId) {
    return (database.select(database.artifactComments)
          ..where(
            (t) => t.artifactId.equals(artifactId) & t.isDeleted.equals(false),
          )
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc),
          ]))
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => models.ArtifactComment(
                  id: row.id,
                  artifactId: row.artifactId,
                  body: row.body,
                  createdAt: row.createdAt,
                  updatedAt: row.updatedAt,
                ),
              )
              .toList(),
        );
  }

  /// Adds a comment and returns its id. Throws [ArgumentError] on blank input
  /// so an empty submit can't create a ghost row.
  Future<String> addComment(String artifactId, String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(body, 'body', 'Comment body must not be blank');
    }

    final id = _uuid.v4();
    final now = DateTime.now();
    await database
        .into(database.artifactComments)
        .insert(
          ArtifactCommentsCompanion.insert(
            id: id,
            artifactId: artifactId,
            body: trimmed,
            createdAt: now,
            updatedAt: Value(now),
          ),
        );
    return id;
  }

  Future<void> updateComment(String commentId, String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(body, 'body', 'Comment body must not be blank');
    }

    await (database.update(
      database.artifactComments,
    )..where((t) => t.id.equals(commentId))).write(
      ArtifactCommentsCompanion(
        body: Value(trimmed),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Soft delete, so the tombstone still reaches the server on next sync.
  Future<void> deleteComment(String commentId) async {
    await (database.update(
      database.artifactComments,
    )..where((t) => t.id.equals(commentId))).write(
      ArtifactCommentsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  models.Artifact _toArtifact(
    ImageMetadataData metadata, {
    required String? noteTitle,
    required int commentCount,
  }) {
    return models.Artifact(
      id: metadata.id,
      imagePath: metadata.imagePath,
      latitude: metadata.latitude,
      longitude: metadata.longitude,
      capturedAt: metadata.capturedAt,
      noteId: metadata.noteId,
      noteTitle: noteTitle,
      commentCount: commentCount,
      analysis: models.Artifact.decodeAnalysis(metadata.analysisResult),
    );
  }
}
