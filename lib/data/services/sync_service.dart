/// Sync service for offline-first data synchronization.
///
/// Monitors network connectivity and syncs local changes with the server.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';
import '../database/app_database.dart';

/// Sync status for tracking sync state
enum SyncStatus { idle, syncing, success, error, offline }

/// Sync result with details
class SyncResult {
  final SyncStatus status;
  final int notesUploaded;
  final int notesDownloaded;
  final int foldersUploaded;
  final int foldersDownloaded;
  final String? errorMessage;
  final DateTime timestamp;

  SyncResult({
    required this.status,
    this.notesUploaded = 0,
    this.notesDownloaded = 0,
    this.foldersUploaded = 0,
    this.foldersDownloaded = 0,
    this.errorMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isSuccess => status == SyncStatus.success;
}

/// Service for handling offline-first sync with backend
class SyncService {
  final ApiService _apiService;
  final AppDatabase _database;
  final Connectivity _connectivity;
  final FlutterSecureStorage _storage;

  static const String _lastSyncKey = 'last_sync_timestamp';

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final StreamController<SyncStatus> _statusController =
      StreamController.broadcast();
  final StreamController<SyncResult> _resultController =
      StreamController.broadcast();

  SyncStatus _currentStatus = SyncStatus.idle;
  DateTime? _lastSyncAt;

  SyncService({
    required ApiService apiService,
    required AppDatabase database,
    Connectivity? connectivity,
    FlutterSecureStorage? storage,
  }) : _apiService = apiService,
       _database = database,
       _connectivity = connectivity ?? Connectivity(),
       _storage = storage ?? const FlutterSecureStorage() {
    _loadLastSyncTime();
  }

  /// Load last sync timestamp from storage
  Future<void> _loadLastSyncTime() async {
    final timestamp = await _storage.read(key: _lastSyncKey);
    if (timestamp != null) {
      _lastSyncAt = DateTime.parse(timestamp);
    }
  }

  /// Save last sync timestamp to storage
  Future<void> _saveLastSyncTime(DateTime timestamp) async {
    _lastSyncAt = timestamp;
    await _storage.write(key: _lastSyncKey, value: timestamp.toIso8601String());
  }

  /// Stream of sync status updates
  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// Stream of sync results
  Stream<SyncResult> get resultStream => _resultController.stream;

  /// Current sync status
  SyncStatus get currentStatus => _currentStatus;

  /// Last successful sync timestamp
  DateTime? get lastSyncAt => _lastSyncAt;

  /// Start monitoring connectivity and auto-sync
  void startMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      // connectivity_plus v6.0.0+ returns List<ConnectivityResult>
      // If list contains any connection type other than none, we are online.
      final hasConnection = !results.contains(ConnectivityResult.none);

      if (hasConnection && _currentStatus != SyncStatus.syncing) {
        // Trigger sync when coming back online
        sync();
      } else if (!hasConnection) {
        _updateStatus(SyncStatus.offline);
      }
    });
  }

  /// Stop monitoring connectivity
  void stopMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// Check if device is online
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  /// Perform full sync with server
  Future<SyncResult> sync() async {
    if (_currentStatus == SyncStatus.syncing) {
      return SyncResult(
        status: SyncStatus.syncing,
        errorMessage: 'Sync already in progress',
      );
    }

    if (!await isOnline()) {
      _updateStatus(SyncStatus.offline);
      return SyncResult(
        status: SyncStatus.offline,
        errorMessage: 'No internet connection',
      );
    }

    _updateStatus(SyncStatus.syncing);

    try {
      // Ensure we have loaded the last sync time
      if (_lastSyncAt == null) {
        await _loadLastSyncTime();
      }

      // Get unsynced local notes and folders
      final localNotes = await _getUnsyncedNotes();
      final localFolders = await _getUnsyncedFolders();
      final localArtifacts = await _getUnsyncedArtifacts();
      final localComments = await _getUnsyncedArtifactComments();

      debugPrint(
        '[SyncService] Syncing ${localNotes.length} notes, ${localFolders.length} folders, '
        '${localArtifacts.length} artifacts, ${localComments.length} comments. Last sync: $_lastSyncAt',
      );

      // Send to server
      final response = await _apiService.post('/sync', {
        'notes': localNotes,
        'folders': localFolders,
        'artifacts': localArtifacts,
        'artifact_comments': localComments,
        'last_sync_at': _lastSyncAt?.toIso8601String(),
      });

      // Apply server changes
      final serverNotes = (response['notes'] as List?) ?? [];
      final serverFolders = (response['folders'] as List?) ?? [];
      final serverArtifacts = (response['artifacts'] as List?) ?? [];
      final serverComments = (response['artifact_comments'] as List?) ?? [];

      await _applyServerChanges(serverNotes, serverFolders);
      await _applyServerArtifactChanges(serverArtifacts, serverComments);

      // Update last sync timestamp
      final newSyncTime = DateTime.parse(response['sync_timestamp'] as String);
      await _saveLastSyncTime(newSyncTime);

      _updateStatus(SyncStatus.success);

      final result = SyncResult(
        status: SyncStatus.success,
        notesUploaded: localNotes.length,
        notesDownloaded: serverNotes.length,
        foldersUploaded: localFolders.length,
        foldersDownloaded: serverFolders.length,
      );

      _resultController.add(result);
      return result;
    } catch (e) {
      debugPrint('[SyncService] Sync error: $e');
      _updateStatus(SyncStatus.error);

      final result = SyncResult(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );

      _resultController.add(result);
      return result;
    }
  }

  /// Get notes that haven't been synced or modified since last sync
  Future<List<Map<String, dynamic>>> _getUnsyncedNotes() async {
    // Get all notes from database
    // Optimization: Filter by updatedAt > _lastSyncAt if possible
    // But for now, we send all modified notes.
    // Ideally we should track a 'syncedAt' column locally too, or just use updatedAt comparison.
    // If we assume strict clock sync (unreliable), comparing updatedAt > lastSyncAt is risky.
    // Better strategy: Send anything where updatedAt > lastSyncAt OR lastSyncAt is null.

    Expression<bool> predicate = const Constant(true);
    if (_lastSyncAt != null) {
      // Add a small buffer to avoid missing updates due to clock skew
      final bufferTime = _lastSyncAt!.subtract(const Duration(seconds: 5));
      predicate =
          _database.notes.updatedAt.isBiggerThanValue(bufferTime) |
          _database.notes.updatedAt.isNull();
      // If updatedAt is null (legacy/new), include it.
      // Actually new notes should have updatedAt.
    }

    final notes = await (_database.select(
      _database.notes,
    )..where((tbl) => predicate)).get();

    // Convert to sync format
    return notes
        .map(
          (note) => {
            'id': note.id,
            'title': note.title,
            'content': note.content,
            'folder_id': note.folderId,
            'audio_path': note.audioPath,
            'date': note.date.toIso8601String(),
            'updated_at': (note.updatedAt ?? note.date)
                .toIso8601String(), // Use updatedAt, fallback to date
            'is_deleted': note.isDeleted,
          },
        )
        .toList();
  }

  /// Get folders that haven't been synced or modified since last sync
  Future<List<Map<String, dynamic>>> _getUnsyncedFolders() async {
    Expression<bool> predicate = const Constant(true);
    if (_lastSyncAt != null) {
      final bufferTime = _lastSyncAt!.subtract(const Duration(seconds: 5));
      predicate =
          _database.folders.updatedAt.isBiggerThanValue(bufferTime) |
          _database.folders.updatedAt.isNull();
    }

    final folders = await (_database.select(
      _database.folders,
    )..where((tbl) => predicate)).get();

    // Convert to sync format
    return folders
        .map(
          (folder) => {
            'id': folder.id,
            'name': folder.name,
            'color': folder.color,
            'updated_at': (folder.updatedAt ?? folder.createdAt)
                .toIso8601String(),
            'is_deleted': folder.isDeleted,
          },
        )
        .toList();
  }

  /// Get artifacts (geotagged photos) modified since the last sync.
  Future<List<Map<String, dynamic>>> _getUnsyncedArtifacts() async {
    Expression<bool> predicate = const Constant(true);
    if (_lastSyncAt != null) {
      final bufferTime = _lastSyncAt!.subtract(const Duration(seconds: 5));
      predicate =
          _database.imageMetadata.updatedAt.isBiggerThanValue(bufferTime) |
          _database.imageMetadata.updatedAt.isNull();
    }

    final artifacts = await (_database.select(
      _database.imageMetadata,
    )..where((tbl) => predicate)).get();

    return artifacts
        .map(
          (artifact) => {
            'id': artifact.id,
            'note_id': artifact.noteId,
            'image_path': artifact.imagePath,
            'latitude': artifact.latitude,
            'longitude': artifact.longitude,
            'analysis_result': artifact.analysisResult,
            'captured_at': artifact.capturedAt.toIso8601String(),
            'updated_at': (artifact.updatedAt ?? artifact.capturedAt)
                .toIso8601String(),
            'is_deleted': artifact.isDeleted,
          },
        )
        .toList();
  }

  /// Get artifact comments modified since the last sync.
  Future<List<Map<String, dynamic>>> _getUnsyncedArtifactComments() async {
    Expression<bool> predicate = const Constant(true);
    if (_lastSyncAt != null) {
      final bufferTime = _lastSyncAt!.subtract(const Duration(seconds: 5));
      predicate =
          _database.artifactComments.updatedAt.isBiggerThanValue(bufferTime) |
          _database.artifactComments.updatedAt.isNull();
    }

    final comments = await (_database.select(
      _database.artifactComments,
    )..where((tbl) => predicate)).get();

    return comments
        .map(
          (comment) => {
            'id': comment.id,
            'artifact_id': comment.artifactId,
            'body': comment.body,
            'created_at': comment.createdAt.toIso8601String(),
            'updated_at': (comment.updatedAt ?? comment.createdAt)
                .toIso8601String(),
            'is_deleted': comment.isDeleted,
          },
        )
        .toList();
  }

  /// Apply artifact and comment changes received from the server.
  ///
  /// Artifacts are written before comments so a comment always has its
  /// artifact present locally.
  Future<void> _applyServerArtifactChanges(
    List<dynamic> serverArtifacts,
    List<dynamic> serverComments,
  ) async {
    for (final data in serverArtifacts) {
      final id = data['id'] as String;
      final isDeleted = data['is_deleted'] as bool? ?? false;
      final updatedAt = DateTime.parse(data['updated_at'] as String);

      if (isDeleted) {
        await (_database.update(
          _database.imageMetadata,
        )..where((t) => t.id.equals(id))).write(
          ImageMetadataCompanion(
            isDeleted: const Value(true),
            updatedAt: Value(updatedAt),
          ),
        );
      } else {
        await _database
            .into(_database.imageMetadata)
            .insertOnConflictUpdate(
              ImageMetadataCompanion.insert(
                id: id,
                // The photo file itself never syncs, so on a second device
                // this path points at a file that isn't there; the UI falls
                // back to a placeholder.
                imagePath: data['image_path'] as String? ?? '',
                latitude: Value(_toDouble(data['latitude'])),
                longitude: Value(_toDouble(data['longitude'])),
                analysisResult: Value(data['analysis_result'] as String?),
                capturedAt: DateTime.parse(data['captured_at'] as String),
                noteId: Value(data['note_id'] as String?),
                updatedAt: Value(updatedAt),
                isDeleted: const Value(false),
              ),
            );
      }
    }

    for (final data in serverComments) {
      final id = data['id'] as String;
      final isDeleted = data['is_deleted'] as bool? ?? false;
      final updatedAt = DateTime.parse(data['updated_at'] as String);

      if (isDeleted) {
        await (_database.update(
          _database.artifactComments,
        )..where((t) => t.id.equals(id))).write(
          ArtifactCommentsCompanion(
            isDeleted: const Value(true),
            updatedAt: Value(updatedAt),
          ),
        );
      } else {
        await _database
            .into(_database.artifactComments)
            .insertOnConflictUpdate(
              ArtifactCommentsCompanion.insert(
                id: id,
                artifactId: data['artifact_id'] as String,
                body: data['body'] as String? ?? '',
                createdAt: DateTime.parse(data['created_at'] as String),
                updatedAt: Value(updatedAt),
                isDeleted: const Value(false),
              ),
            );
      }
    }
  }

  /// JSON numbers arrive as int when the server stores a whole-number
  /// coordinate, so a blind `as double?` cast would throw.
  static double? _toDouble(Object? value) => (value as num?)?.toDouble();

  /// Apply changes received from server
  Future<void> _applyServerChanges(
    List<dynamic> serverNotes,
    List<dynamic> serverFolders,
  ) async {
    // Apply folder changes first (notes may reference them)
    for (final folderData in serverFolders) {
      final folderId = folderData['id'] as String;
      final isDeleted = folderData['is_deleted'] as bool? ?? false;

      if (isDeleted) {
        // Soft delete locally - DO NOT hard delete otherwise we lose the tombstone
        // and might re-sync it if we have a stale local state.
        // Actually, if server says deleted, we should mark as deleted locally.
        await (_database.update(
          _database.folders,
        )..where((f) => f.id.equals(folderId))).write(
          FoldersCompanion(
            isDeleted: const Value(true),
            updatedAt: Value(
              DateTime.parse(folderData['updated_at'] as String),
            ),
          ),
        );
      } else {
        // Upsert folder
        await _database
            .into(_database.folders)
            .insertOnConflictUpdate(
              FoldersCompanion.insert(
                id: folderId,
                name: folderData['name'] as String,
                color: Value(folderData['color'] as String? ?? '#E8B731'),
                createdAt: DateTime.parse(
                  folderData['created_at'] as String? ??
                      DateTime.now().toIso8601String(),
                ),
                updatedAt: Value(
                  DateTime.parse(folderData['updated_at'] as String),
                ),
                isDeleted: const Value(false),
              ),
            );
      }
    }

    // Apply note changes
    for (final noteData in serverNotes) {
      final noteId = noteData['id'] as String;
      final isDeleted = noteData['is_deleted'] as bool? ?? false;

      if (isDeleted) {
        // Soft delete locally
        await (_database.update(
          _database.notes,
        )..where((n) => n.id.equals(noteId))).write(
          NotesCompanion(
            isDeleted: const Value(true),
            updatedAt: Value(DateTime.parse(noteData['updated_at'] as String)),
          ),
        );
      } else {
        // Upsert note
        await _database
            .into(_database.notes)
            .insertOnConflictUpdate(
              NotesCompanion.insert(
                id: noteId,
                title: noteData['title'] as String? ?? '',
                content: noteData['content'] as String? ?? '',
                date: DateTime.parse(noteData['date'] as String),
                audioPath: Value(noteData['audio_path'] as String?),
                folderId: Value(noteData['folder_id'] as String?),
                updatedAt: Value(
                  DateTime.parse(noteData['updated_at'] as String),
                ),
                isDeleted: const Value(false),
              ),
            );
      }
    }
  }

  void _updateStatus(SyncStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  /// Dispose resources
  void dispose() {
    stopMonitoring();
    _statusController.close();
    _resultController.close();
  }
}
