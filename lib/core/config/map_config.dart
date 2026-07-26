/// Mapbox configuration.
///
/// The public access token is injected at build time and is never committed:
///
///     flutter run --dart-define=MAPBOX_ACCESS_TOKEN=pk.your_token
///
/// or, to avoid repeating it, put it in a gitignored JSON file and use
/// `--dart-define-from-file=mapbox.json`.
///
/// The separate *secret* download token (`sk.…`) is only needed to compile the
/// native SDK and lives outside the repo entirely — in `~/.gradle/gradle.properties`
/// for Android and `~/.netrc` for iOS.
abstract final class MapConfig {
  static const String accessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
  );

  /// False when the app was built without a token. The map page shows a
  /// configuration message instead of a blank canvas.
  static bool get hasAccessToken => accessToken.isNotEmpty;

  /// Camera zoom used when focusing a single artifact.
  static const double focusZoom = 15.0;

  /// Fallback zoom when only one artifact exists, so the map isn't
  /// zoomed all the way out onto an empty world.
  static const double singleArtifactZoom = 13.0;
}
