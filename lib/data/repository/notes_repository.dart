import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../current_owner_holder.dart';
import '../database/app_database.dart';

class NotesRepository {
  final AppDatabase database;

  /// The account local writes are stamped with and local reads are scoped
  /// to (null = guest). Shared with [SessionCubit] via DI so both stay in
  /// sync with the current auth state.
  final CurrentOwnerHolder _owner;

  NotesRepository(this.database, {CurrentOwnerHolder? ownerHolder})
    : _owner = ownerHolder ?? CurrentOwnerHolder();

  /// Owner filter shared by every watch query: a signed-in user sees their
  /// own rows plus still-unclaimed guest rows (about to be claimed), a
  /// guest sees only unclaimed rows, and another account's rows are always
  /// excluded. This -- plus stamping `ownerKey` on every write below -- is
  /// what stops one account's notes/folders from leaking into another's.
  Expression<bool> _ownerFilter(GeneratedColumn<String> ownerKey) {
    final owner = _owner.value;
    return owner == null
        ? ownerKey.isNull()
        : (ownerKey.equals(owner) | ownerKey.isNull());
  }

  // ==================== NOTES OPERATIONS ====================

  /// Stream of all notes, ordered by date descending
  Stream<List<Note>> watchAllNotes() {
    return (database.select(database.notes)
          ..where((t) => t.isDeleted.equals(false) & _ownerFilter(t.ownerKey))
          ..orderBy([
            (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Get a single note by ID
  Future<Note?> getNoteById(String id) async {
    return (database.select(
      database.notes,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Insert a new note
  Future<void> insertNote(Note note) async {
    await database
        .into(database.notes)
        .insert(
          NotesCompanion(
            id: Value(note.id),
            title: Value(note.title),
            content: Value(note.content),
            date: Value(note.date),
            audioPath: Value(note.audioPath),
            folderId: Value(note.folderId),
            updatedAt: Value(DateTime.now()),
            pendingSync: const Value(true),
            isDeleted: const Value(false),
            ownerKey: Value(_owner.value),
            authorId: Value(_owner.value),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Update an existing note.
  ///
  /// Deliberately omits `date` from the write: `date` is the immutable diary
  /// date and must never be touched by an edit, only by the initial insert.
  Future<void> updateNote(Note note) async {
    await (database.update(
      database.notes,
    )..where((t) => t.id.equals(note.id))).write(
      NotesCompanion(
        title: Value(note.title),
        content: Value(note.content),
        audioPath: Value(note.audioPath),
        folderId: Value(note.folderId),
        updatedAt: Value(DateTime.now()),
        pendingSync: const Value(true),
        ownerKey: Value(_owner.value),
        authorId: Value(_owner.value),
      ),
    );
  }

  /// Delete a note and its associated audio files
  Future<void> deleteNote(String id) async {
    // First retrieve the note to get audioPath
    final note = await getNoteById(id);
    if (note != null && note.audioPath != null) {
      final path = note.audioPath!;
      try {
        final file = File(path);
        if (await file.exists()) {
          if (path.endsWith('.json')) {
            // It's a metadata file, read it to find segments
            try {
              final jsonString = await file.readAsString();
              final List<dynamic> jsonList = jsonDecode(jsonString);
              for (final item in jsonList) {
                if (item is Map && item.containsKey('filePath')) {
                  final audioFile = File(item['filePath'] as String);
                  if (await audioFile.exists()) {
                    await audioFile.delete();
                  }
                }
              }
            } catch (e) {
              // Ignore JSON parse errors, just delete the meta file
            }
          }
          // Delete the main file (audio or json)
          await file.delete();
        }
      } catch (e) {
        // Ignore file deletion errors
      }
    }

    // Soft delete locally so it can be synced
    await (database.update(
      database.notes,
    )..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
        pendingSync: const Value(true),
        ownerKey: Value(_owner.value),
        authorId: Value(_owner.value),
      ),
    );
  }

  /// Hard delete a note and its associated audio files locally
  Future<void> hardDeleteNote(String id) async {
    // Delete potential physical files first
    final note = await getNoteById(id);
    if (note != null && note.audioPath != null) {
      final path = note.audioPath!;
      try {
        final file = File(path);
        if (await file.exists()) {
          if (path.endsWith('.json')) {
            try {
              final jsonString = await file.readAsString();
              final List<dynamic> jsonList = jsonDecode(jsonString);
              for (final item in jsonList) {
                if (item is Map && item.containsKey('filePath')) {
                  final audioFile = File(item['filePath'] as String);
                  if (await audioFile.exists()) {
                    await audioFile.delete();
                  }
                }
              }
            } catch (e) {
              // Ignore
            }
          }
          await file.delete();
        }
      } catch (e) {
        // Ignore
      }
    }

    // Hard delete from DB
    await (database.delete(database.notes)..where((t) => t.id.equals(id))).go();
  }

  /// Move note to a folder
  Future<void> moveNoteToFolder(String noteId, String? folderId) async {
    await (database.update(
      database.notes,
    )..where((t) => t.id.equals(noteId))).write(
      NotesCompanion(
        folderId: Value(folderId),
        updatedAt: Value(DateTime.now()),
        pendingSync: const Value(true),
        ownerKey: Value(_owner.value),
        authorId: Value(_owner.value),
      ),
    );
  }

  /// Watch notes in a specific folder (null = All Notes / uncategorized)
  Stream<List<Note>> watchNotesInFolder(String? folderId) {
    if (folderId == null) {
      // All notes without a folder
      return (database.select(database.notes)
            ..where(
              (t) =>
                  t.folderId.isNull() &
                  t.isDeleted.equals(false) &
                  _ownerFilter(t.ownerKey),
            )
            ..orderBy([
              (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
            ]))
          .watch();
    }
    return (database.select(database.notes)
          ..where(
            (t) =>
                t.folderId.equals(folderId) &
                t.isDeleted.equals(false) &
                _ownerFilter(t.ownerKey),
          )
          ..orderBy([
            (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  // ==================== FOLDERS OPERATIONS ====================

  /// Stream of all folders, ordered by creation date
  Stream<List<Folder>> watchAllFolders() {
    return (database.select(database.folders)
          ..where((t) => t.isDeleted.equals(false) & _ownerFilter(t.ownerKey))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  /// Get a single folder by ID
  Future<Folder?> getFolderById(String id) async {
    return (database.select(
      database.folders,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Create a new folder
  Future<void> createFolder(Folder folder) async {
    await database
        .into(database.folders)
        .insert(
          FoldersCompanion(
            id: Value(folder.id),
            name: Value(folder.name),
            color: Value(folder.color),
            createdAt: Value(folder.createdAt),
            updatedAt: Value(DateTime.now()),
            pendingSync: const Value(true),
            isDeleted: const Value(false),
            ownerKey: Value(_owner.value),
            authorId: Value(_owner.value),
          ),
        );
  }

  /// Update an existing folder
  Future<void> updateFolder(Folder folder) async {
    await (database.update(
      database.folders,
    )..where((t) => t.id.equals(folder.id))).write(
      FoldersCompanion(
        name: Value(folder.name),
        color: Value(folder.color),
        updatedAt: Value(DateTime.now()),
        pendingSync: const Value(true),
        ownerKey: Value(_owner.value),
        authorId: Value(_owner.value),
      ),
    );
  }

  /// Delete a folder and move its notes to "All Notes" (null folderId)
  Future<void> deleteFolder(String folderId) async {
    // Move all notes in this folder to "All Notes"
    await (database.update(
      database.notes,
    )..where((t) => t.folderId.equals(folderId))).write(
      NotesCompanion(
        folderId: const Value(null),
        updatedAt: Value(DateTime.now()),
        pendingSync: const Value(true),
        ownerKey: Value(_owner.value),
        authorId: Value(_owner.value),
      ),
    );

    // Soft delete the folder
    await (database.update(
      database.folders,
    )..where((t) => t.id.equals(folderId))).write(
      FoldersCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
        pendingSync: const Value(true),
        ownerKey: Value(_owner.value),
        authorId: Value(_owner.value),
      ),
    );
  }

  /// Get count of notes in each folder
  Stream<Map<String, int>> watchFolderNoteCounts() {
    final count = database.notes.id.count();
    final query = database.selectOnly(database.notes)
      ..addColumns([database.notes.folderId, count])
      ..where(
        database.notes.isDeleted.equals(false) &
            _ownerFilter(database.notes.ownerKey),
      )
      ..groupBy([database.notes.folderId]);

    return query.watch().map((rows) {
      final map = <String, int>{};
      for (final row in rows) {
        final folderId = row.read(database.notes.folderId);
        final c = row.read(count);
        // Use 'all_notes' key for null folderId
        map[folderId ?? 'all_notes'] = c ?? 0;
      }
      return map;
    });
  }

  /// Get count of notes without a folder (All Notes)
  Stream<int> watchAllNotesCount() {
    final count = database.notes.id.count();
    final query = database.selectOnly(database.notes)
      ..addColumns([count])
      ..where(
        database.notes.folderId.isNull() &
            database.notes.isDeleted.equals(false) &
            _ownerFilter(database.notes.ownerKey),
      );

    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  /// Copies [id]'s current local state into a brand-new note.
  ///
  /// Called when the server refuses a write because someone else edited the
  /// same note first. Without this the server's version would simply
  /// overwrite the local one and a day of field notes would vanish with no
  /// trace -- the outcome the revision guard exists to prevent.
  ///
  /// [at] is injected rather than read from the clock so the label is
  /// testable. The fork deliberately has no `baseRevision`: it has never been
  /// to the server, so it uploads as a create instead of racing again against
  /// the revision it just lost to.
  Future<Note> forkNote(String id, {required DateTime at}) async {
    final original = await getNoteById(id);
    if (original == null) {
      throw StateError('cannot fork a note that does not exist: $id');
    }

    String two(int n) => n.toString().padLeft(2, '0');
    final label = '${two(at.hour)}:${two(at.minute)}';
    final forkId = const Uuid().v4();

    await database
        .into(database.notes)
        .insert(
          NotesCompanion.insert(
            id: forkId,
            title: '${original.title} (версия $label)',
            content: original.content,
            date: original.date,
            audioPath: Value(original.audioPath),
            folderId: Value(original.folderId),
            updatedAt: Value(at),
            pendingSync: const Value(true),
            isDeleted: const Value(false),
            ownerKey: Value(_owner.value),
            authorId: Value(_owner.value),
            baseRevision: const Value(null),
          ),
        );

    return (await getNoteById(forkId))!;
  }

  /// How many of this owner's notes carry local changes the server has not
  /// acknowledged yet.
  ///
  /// Used to warn before a sign-out that would strand them: the rows survive
  /// on the device, but `ownerKey` scoping hides them until the same account
  /// signs back in, so from the user's side the work simply vanishes.
  ///
  /// Deleted rows are counted too -- a pending deletion is unsent work in the
  /// same way an edit is.
  Future<int> pendingSyncCount() async {
    final count = database.notes.id.count();
    final query = database.selectOnly(database.notes)
      ..addColumns([count])
      ..where(
        database.notes.pendingSync.equals(true) &
            _ownerFilter(database.notes.ownerKey),
      );

    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }
}
