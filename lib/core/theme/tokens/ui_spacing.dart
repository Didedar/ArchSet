/// Named spacing scale used in place of magic-number [EdgeInsets]/[SizedBox] values.
class UiSpacing {
  const UiSpacing({
    this.xs = 4,
    this.sm = 8,
    this.md = 16,
    this.lg = 24,
    this.xl = 32,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UiSpacing &&
          runtimeType == other.runtimeType &&
          xs == other.xs &&
          sm == other.sm &&
          md == other.md &&
          lg == other.lg &&
          xl == other.xl;

  @override
  int get hashCode => Object.hash(xs, sm, md, lg, xl);
}
