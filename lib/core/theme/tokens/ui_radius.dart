/// Named corner-radius scale covering the dominant values already in use
/// across the app (buttons/chips at [md], cards/sheets at [lg], pill-shaped
/// controls at [pill]). True one-off radii stay local to their widget.
class UiRadius {
  const UiRadius({
    this.sm = 4,
    this.md = 12,
    this.lg = 16,
    this.xl = 20,
    this.pill = 30,
  });

  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double pill;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UiRadius &&
          runtimeType == other.runtimeType &&
          sm == other.sm &&
          md == other.md &&
          lg == other.lg &&
          xl == other.xl &&
          pill == other.pill;

  @override
  int get hashCode => Object.hash(sm, md, lg, xl, pill);
}
