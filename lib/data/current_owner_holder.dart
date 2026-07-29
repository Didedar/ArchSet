/// The account that owns local data right now (null = guest/unclaimed).
/// Written by the session layer on auth transitions; read by the repository
/// and sync layer to scope reads/writes to the current owner.
class CurrentOwnerHolder {
  CurrentOwnerHolder([this.value]);
  String? value;
}
