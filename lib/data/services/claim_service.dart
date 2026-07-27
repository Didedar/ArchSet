import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Claims guest-owned (unclaimed) local data for a freshly authenticated
/// account and flags it for the next push. "Guest" rows have ownerKey IS NULL.
/// Rows already owned by another account keep their owner + dirty flag, so
/// switching accounts on a shared device never re-owns/re-pushes the previous
/// account's data. updatedAt is deliberately left untouched (claim changes
/// ownership, not content, so the row keeps its real modification time for LWW).
class ClaimService {
  ClaimService(this._database);
  final AppDatabase _database;

  /// Claims all unclaimed notes and folders for [ownerId] in one transaction;
  /// returns the total rows claimed.
  Future<int> claimGuestData(String ownerId) {
    return _database.transaction(() async {
      final notesClaimed =
          await (_database.update(
            _database.notes,
          )..where((t) => t.ownerKey.isNull())).write(
            NotesCompanion(
              ownerKey: Value(ownerId),
              pendingSync: const Value(true),
            ),
          );
      final foldersClaimed =
          await (_database.update(
            _database.folders,
          )..where((t) => t.ownerKey.isNull())).write(
            FoldersCompanion(
              ownerKey: Value(ownerId),
              pendingSync: const Value(true),
            ),
          );
      return notesClaimed + foldersClaimed;
    });
  }
}
