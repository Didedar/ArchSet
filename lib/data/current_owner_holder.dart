import 'dart:async';

/// The account that owns local data right now (null = guest/unclaimed).
/// Written by the session layer on auth transitions; read by the repository
/// and sync layer to scope reads/writes to the current owner.
///
/// Observable on purpose. A database watch compiles its WHERE clause once,
/// when it is subscribed to, and re-runs *that* query whenever the tables
/// change. Signing in mid-session changes whose rows these are without
/// touching a single table, so a stream opened while the app was a guest went
/// on asking the guest's question forever: an empty diary that stayed empty
/// even as new entries were written into it. [changes] is what lets a scoped
/// query know it has to be rebuilt.
class CurrentOwnerHolder {
  CurrentOwnerHolder([String? value]) : _value = value;

  String? _value;
  final StreamController<String?> _changes =
      StreamController<String?>.broadcast();

  String? get value => _value;

  set value(String? next) {
    if (_value == next) return;
    _value = next;
    if (!_changes.isClosed) _changes.add(next);
  }

  /// The current owner, then every subsequent change.
  ///
  /// Emits immediately so a subscriber does not have to wait for the first
  /// transition to get an answer.
  Stream<String?> get changes async* {
    yield _value;
    yield* _changes.stream;
  }

  Future<void> dispose() => _changes.close();
}
