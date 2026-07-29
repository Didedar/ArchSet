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
  final List<Duration> _retryBackoff;

  static const String _lastSyncKey = 'last_sync_timestamp';

  /// Un-namespaced signed-in account id (mirrors
  /// `AuthStorageKeys.currentOwnerId`); absent means guest. Sync is a no-op
  /// for guests -- there is no account to sync to yet.
  static const String _ownerIdKey = 'current_owner_id';

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
    List<Duration>? retryBackoff,
  }) : _apiService = apiService,
       _database = database,
       _connectivity = connectivity ?? Connectivity(),
       _storage = storage ?? const FlutterSecureStorage(),
       _retryBackoff =
           retryBackoff ??
           const [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 4)] {
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

  /// Check if device is online (connectivity only -- does not probe the
  /// server). Kept as a lightweight public helper; [sync] itself gates on
  /// [_isReachable], which additionally confirms the server responds.
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  /// True only when there's a network interface up AND the backend answers
  /// its health check. A phone can report "connected to wifi" while the
  /// backend itself is unreachable (captive portal, VPN, server down), so
  /// connectivity alone would send [sync] straight into the retry loop.
  Future<bool> _isReachable() async {
    final results = await _connectivity.checkConnectivity();
    if (results.contains(ConnectivityResult.none)) return false;
    return _apiService.checkHealth();
  }

  /// POSTs the sync payload, retrying with backoff on failure. Rethrows once
  /// [_retryBackoff] is exhausted so the caller's catch-all in [sync] can
  /// turn it into a [SyncStatus.error] result.
  Future<Map<String, dynamic>> _pushWithRetry(
    Map<String, dynamic> payload,
  ) async {
    var attempt = 0;
    while (true) {
      try {
        final response = await _apiService.post('/sync', payload);
        return response as Map<String, dynamic>;
      } catch (_) {
        if (attempt >= _retryBackoff.length) rethrow;
        await Future.delayed(_retryBackoff[attempt++]);
      }
    }
  }

  /// Perform full sync with server
  Future<SyncResult> sync() async {
    if (_currentStatus == SyncStatus.syncing) {
      return SyncResult(
        status: SyncStatus.syncing,
        errorMessage: 'Sync already in progress',
      );
    }

    // Guests have no account to sync to yet -- a local-only guest note is
    // claimed on register/login, not synced beforehand.
    final ownerId = await _storage.read(key: _ownerIdKey);
    if (ownerId == null) {
      return SyncResult(status: SyncStatus.idle, errorMessage: 'Not signed in');
    }

    if (!await _isReachable()) {
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

      // Get unsynced (pendingSync == true) local notes and folders owned by
      // the currently authenticated account -- never another account's.
      final localNotes = await _getUnsyncedNotes(ownerId);
      final localFolders = await _getUnsyncedFolders(ownerId);
      final localArtifacts = await _getUnsyncedArtifacts();
      final localComments = await _getUnsyncedArtifactComments();

      debugPrint(
        '[SyncService] Syncing ${localNotes.length} notes, ${localFolders.length} folders, '
        '${localArtifacts.length} artifacts, ${localComments.length} comments. Last sync: $_lastSyncAt',
      );

      // Send to server (with retry/backoff)
      final response = await _pushWithRetry({
        'notes': localNotes.map(_noteToSyncMap).toList(),
        'folders': localFolders.map(_folderToSyncMap).toList(),
        'artifacts': localArtifacts,
        'artifact_comments': localComments,
        'last_sync_at': _lastSyncAt?.toIso8601String(),
      });

      // Only clear the dirty flag for exactly the rows just pushed, matched
      // on id AND updatedAt -- a row edited again mid-round-trip has a new
      // updatedAt by the time this runs, so it won't match and stays dirty.
      // This runs BEFORE applying server changes below: if the server
      // response happens to echo back the same rows we just pushed, applying
      // it first could stamp a new updatedAt and make the match below miss,
      // leaving a successfully-synced row stuck dirty.
      await _clearPendingNotes(localNotes);
      await _clearPendingFolders(localFolders);

      // Apply server changes
      final serverNotes = (response['notes'] as List?) ?? [];
      final serverFolders = (response['folders'] as List?) ?? [];
      final serverArtifacts = (response['artifacts'] as List?) ?? [];
      final serverComments = (response['artifact_comments'] as List?) ?? [];

      await _applyServerChanges(serverNotes, serverFolders, ownerId);
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

  /// Get local notes with a pending (unsynced) local change, owned by
  /// [ownerId]. The owner filter is what stops a previous account's still-
  /// dirty rows on a shared device from being swept into a different
  /// account's push payload.
  Future<List<Note>> _getUnsyncedNotes(String ownerId) async {
    return (_database.select(_database.notes)..where(
          (tbl) =>
              tbl.pendingSync.equals(true) & tbl.ownerKey.equals(ownerId),
        ))
        .get();
  }

  /// Get local folders with a pending (unsynced) local change, owned by
  /// [ownerId]. See [_getUnsyncedNotes].
  Future<List<Folder>> _getUnsyncedFolders(String ownerId) async {
    return (_database.select(_database.folders)..where(
          (tbl) =>
              tbl.pendingSync.equals(true) & tbl.ownerKey.equals(ownerId),
        ))
        .get();
  }

  /// Push payload shape for a single note. Keys match what the backend's
  /// `/sync` endpoint already expects.
  Map<String, dynamic> _noteToSyncMap(Note note) => {
    'id': note.id,
    'title': note.title,
    'content': note.content,
    'folder_id': note.folderId,
    'audio_path': note.audioPath,
    'date': note.date.toIso8601String(),
    'updated_at': (note.updatedAt ?? note.date)
        .toIso8601String(), // Use updatedAt, fallback to date
    'is_deleted': note.isDeleted,
  };

  /// Push payload shape for a single folder.
  Map<String, dynamic> _folderToSyncMap(Folder folder) => {
    'id': folder.id,
    'name': folder.name,
    'color': folder.color,
    'updated_at': (folder.updatedAt ?? folder.createdAt).toIso8601String(),
    'is_deleted': folder.isDeleted,
  };

  /// Clears `pendingSync` for exactly the note rows just pushed, matching on
  /// id AND updatedAt so a note re-edited while the push was in flight (its
  /// updatedAt already moved on) keeps its dirty flag set.
  Future<void> _clearPendingNotes(List<Note> pushed) async {
    for (final n in pushed) {
      await (_database.update(_database.notes)..where(
            (t) =>
                t.id.equals(n.id) &
                (n.updatedAt == null
                    ? t.updatedAt.isNull()
                    : t.updatedAt.equals(n.updatedAt!)),
          ))
          .write(const NotesCompanion(pendingSync: Value(false)));
    }
  }

  /// Folder counterpart of [_clearPendingNotes].
  Future<void> _clearPendingFolders(List<Folder> pushed) async {
    for (final f in pushed) {
      await (_database.update(_database.folders)..where(
            (t) =>
                t.id.equals(f.id) &
                (f.updatedAt == null
                    ? t.updatedAt.isNull()
                    : t.updatedAt.equals(f.updatedAt!)),
          ))
          .write(const FoldersCompanion(pendingSync: Value(false)));
    }
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

  /// Parses a nullable ISO-8601 timestamp. The server is expected to always
  /// send `updated_at`, but a note's `date` can legitimately arrive as null.
  static DateTime? _parseDate(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  /// A server row loses when the local copy has unpushed edits, or is at
  /// least as new (equal timestamps => no-op, which also neutralises the
  /// echo of a row we just pushed and cleared).
  bool _serverLoses(
    DateTime? localUpdatedAt,
    bool localPending,
    DateTime serverUpdatedAt,
  ) {
    if (localPending) return true;
    if (localUpdatedAt == null) return false;
    return !localUpdatedAt.isBefore(serverUpdatedAt); // local >= server
  }

  /// Apply changes received from server.
  ///
  /// Runs inside a single transaction so a mid-apply failure can't leave
  /// folders and notes in an inconsistent state. Each row is checked against
  /// the local copy via [_serverLoses] before being written: a local row
  /// that still has unpushed edits, or is already at least as new as the
  /// incoming one, keeps its local state instead of being clobbered by a
  /// stale server echo (see C4/C5).
  ///
  /// Every upserted row is stamped with [ownerId]: the backend's `/sync`
  /// pull is already scoped to the authenticated account, so anything it
  /// returns belongs to [ownerId]. Stamping it locally is what stops a
  /// pulled row from silently reading as "unclaimed" (ownerKey null) and
  /// leaking into a different account's view/claim/push later.
  Future<void> _applyServerChanges(
    List<dynamic> serverNotes,
    List<dynamic> serverFolders,
    String ownerId,
  ) async {
    await _database.transaction(() async {
      // Apply folder changes first (notes may reference them)
      for (final folderData in serverFolders) {
        final folderId = folderData['id'] as String;
        final isDeleted = folderData['is_deleted'] as bool? ?? false;
        final serverUpdatedAt =
            _parseDate(folderData['updated_at']) ?? DateTime.now();

        final local = await (_database.select(
          _database.folders,
        )..where((f) => f.id.equals(folderId))).getSingleOrNull();
        if (local != null &&
            _serverLoses(
              local.updatedAt,
              local.pendingSync,
              serverUpdatedAt,
            )) {
          continue;
        }

        if (isDeleted) {
          // Soft delete locally - DO NOT hard delete otherwise we lose the
          // tombstone and might re-sync it if we have a stale local state.
          await (_database.update(
            _database.folders,
          )..where((f) => f.id.equals(folderId))).write(
            FoldersCompanion(
              isDeleted: const Value(true),
              updatedAt: Value(serverUpdatedAt),
              pendingSync: const Value(false),
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
                  createdAt:
                      _parseDate(folderData['created_at']) ?? serverUpdatedAt,
                  updatedAt: Value(serverUpdatedAt),
                  isDeleted: const Value(false),
                  pendingSync: const Value(false),
                  ownerKey: Value(ownerId),
                ),
              );
        }
      }

      // Apply note changes
      for (final noteData in serverNotes) {
        final noteId = noteData['id'] as String;
        final isDeleted = noteData['is_deleted'] as bool? ?? false;
        final serverUpdatedAt =
            _parseDate(noteData['updated_at']) ?? DateTime.now();

        final local = await (_database.select(
          _database.notes,
        )..where((n) => n.id.equals(noteId))).getSingleOrNull();
        if (local != null &&
            _serverLoses(
              local.updatedAt,
              local.pendingSync,
              serverUpdatedAt,
            )) {
          continue;
        }

        if (isDeleted) {
          // Soft delete locally
          await (_database.update(
            _database.notes,
          )..where((n) => n.id.equals(noteId))).write(
            NotesCompanion(
              isDeleted: const Value(true),
              updatedAt: Value(serverUpdatedAt),
              pendingSync: const Value(false),
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
                  date: _parseDate(noteData['date']) ?? serverUpdatedAt,
                  audioPath: Value(noteData['audio_path'] as String?),
                  folderId: Value(noteData['folder_id'] as String?),
                  updatedAt: Value(serverUpdatedAt),
                  isDeleted: const Value(false),
                  pendingSync: const Value(false),
                  ownerKey: Value(ownerId),
                ),
              );
        }
      }
    });
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
