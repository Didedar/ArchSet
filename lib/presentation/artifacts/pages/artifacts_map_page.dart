import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../core/config/map_config.dart';
import '../../../core/di/app_scope.dart';
import '../../../core/localization/app_strings.dart';
import '../../../data/models/artifact.dart';
import '../../../data/repository/artifacts_repository.dart';
import '../../editor/pages/diary_edit_page.dart';
import '../../locale/bloc/locale_bloc.dart';
import '../bloc/artifacts_map_bloc.dart';
import '../widgets/artifact_detail_sheet.dart';
import '../widgets/artifact_marker.dart';
import '../widgets/unlocated_artifacts_sheet.dart';

/// Fullscreen Mapbox map of every geotagged artifact photographed in a note.
class ArtifactsMapPage extends StatelessWidget {
  const ArtifactsMapPage({super.key, this.noteId, this.title});

  /// Show only the finds photographed in this entry. Null is the whole dig.
  final String? noteId;

  /// Heading for the pill. Defaults to the whole-dig title; an entry-scoped
  /// map passes its own so the screen says which trench you are looking at.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final repository = context.di.artifacts.repository;
    return BlocProvider(
      create: (_) =>
          ArtifactsMapBloc(repository: repository, noteId: noteId)
            ..add(const ArtifactsMapSubscriptionRequested()),
      child: _ArtifactsMapView(repository: repository, title: title),
    );
  }
}

class _ArtifactsMapView extends StatefulWidget {
  const _ArtifactsMapView({required this.repository, this.title});

  final ArtifactsRepository repository;
  final String? title;

  @override
  State<_ArtifactsMapView> createState() => _ArtifactsMapViewState();
}

class _ArtifactsMapViewState extends State<_ArtifactsMapView> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _annotationManager;

  /// Maps a Mapbox annotation id back to the artifact it represents; the tap
  /// callback only hands us the annotation.
  final Map<String, Artifact> _artifactsByAnnotationId = {};

  /// Guards against re-fitting the camera on every stream emission — the user
  /// would lose their pan/zoom whenever a comment was added.
  bool _hasFittedCamera = false;

  List<Artifact> _renderedArtifacts = const [];

  @override
  void initState() {
    super.initState();
    if (MapConfig.hasAccessToken) {
      MapboxOptions.setAccessToken(MapConfig.accessToken);
    }
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    // The scale bar adds clutter over a dense pin cluster.
    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    final manager = await mapboxMap.annotations.createPointAnnotationManager();
    if (!mounted) return;
    _annotationManager = manager;
    manager.tapEvents(onTap: _onAnnotationTapped);

    // The bloc may already have emitted before the platform view was ready.
    final state = context.read<ArtifactsMapBloc>().state;
    if (state is ArtifactsMapLoadSuccess) {
      await _syncAnnotations(state.artifacts);
    }
  }

  void _onAnnotationTapped(PointAnnotation annotation) {
    final artifact = _artifactsByAnnotationId[annotation.id];
    if (artifact != null) _openDetailSheet(artifact);
  }

  Future<void> _openDetailSheet(Artifact artifact) async {
    final noteId = await ArtifactDetailSheet.show(
      context,
      artifact: artifact,
      repository: widget.repository,
    );
    if (noteId == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => DiaryEditPage(noteId: noteId)),
    );
  }

  /// Rebuilds the pin layer to match [artifacts].
  ///
  /// `deleteAll` then recreate is intentional: the artifact count is bounded by
  /// how many finds a person photographs, and diffing annotation-by-annotation
  /// would add real complexity for no perceptible gain at this scale.
  Future<void> _syncAnnotations(List<Artifact> artifacts) async {
    final manager = _annotationManager;
    if (manager == null) return;
    // listEquals, not `==`: Dart list equality is identity, so comparing the
    // lists directly would never match and every emission would redraw.
    if (listEquals(_renderedArtifacts, artifacts)) return;

    _renderedArtifacts = artifacts;
    await manager.deleteAll();
    _artifactsByAnnotationId.clear();

    if (artifacts.isEmpty) return;
    if (!mounted) return;

    final theme = Theme.of(context);
    final markerBytes = await ArtifactMarker.build(
      fill: theme.colorScheme.primary,
      border: Colors.white,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );

    // createMulti preserves input order, so zip the results back to artifacts.
    final created = await manager.createMulti([
      for (final artifact in artifacts)
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(artifact.longitude!, artifact.latitude!),
          ),
          image: markerBytes,
          iconSize: 1.0,
          iconAnchor: IconAnchor.BOTTOM,
        ),
    ]);

    for (var i = 0; i < created.length && i < artifacts.length; i++) {
      final annotation = created[i];
      if (annotation != null) {
        _artifactsByAnnotationId[annotation.id] = artifacts[i];
      }
    }

    if (!_hasFittedCamera) {
      _hasFittedCamera = true;
      await _fitCameraTo(artifacts);
    }
  }

  Future<void> _fitCameraTo(List<Artifact> artifacts) async {
    final map = _mapboxMap;
    if (map == null || artifacts.isEmpty) return;

    final points = [
      for (final artifact in artifacts)
        Point(coordinates: Position(artifact.longitude!, artifact.latitude!)),
    ];

    // A single point has no extent to fit, so cameraForCoordinatesPadding
    // would return a meaningless zoom.
    if (points.length == 1) {
      await map.setCamera(
        CameraOptions(center: points.first, zoom: MapConfig.singleArtifactZoom),
      );
      return;
    }

    final camera = await map.cameraForCoordinatesPadding(
      points,
      CameraOptions(),
      MbxEdgeInsets(top: 80, left: 60, bottom: 140, right: 60),
      MapConfig.focusZoom,
      null,
    );
    await map.setCamera(camera);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<LocaleBloc>().state.locale;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: MapConfig.hasAccessToken
          ? _buildMap(context, theme, locale)
          : _MapUnavailable(locale: locale),
    );
  }

  Widget _buildMap(BuildContext context, ThemeData theme, Locale locale) {
    return BlocConsumer<ArtifactsMapBloc, ArtifactsMapState>(
      listenWhen: (previous, current) => current is ArtifactsMapLoadSuccess,
      listener: (context, state) {
        if (state is ArtifactsMapLoadSuccess) {
          _syncAnnotations(state.artifacts);
        }
      },
      builder: (context, state) {
        final isEmpty = state is ArtifactsMapLoadSuccess && state.isEmpty;
        final unlocatedCount = state is ArtifactsMapLoadSuccess
            ? state.unlocatedCount
            : 0;

        // SizedBox.expand is load-bearing, not decoration. Scaffold hands its
        // body *loose* constraints, and a Stack under loose constraints sizes
        // itself to its largest NON-positioned child. Every child here is
        // positioned except the SafeArea header row, so the Stack collapsed to
        // the height of the back button -- and `Positioned.fill` faithfully
        // filled that ~110px box. That is why the map rendered as a strip
        // across the top with blank scaffold below it.
        return SizedBox.expand(
          child: Stack(
            children: [
              Positioned.fill(
                child: MapWidget(
                  key: const ValueKey('artifacts_map'),
                  styleUri: theme.brightness == Brightness.dark
                      ? MapboxStyles.DARK
                      : MapboxStyles.OUTDOORS,
                  onMapCreated: _onMapCreated,
                ),
              ),
              if (state is ArtifactsMapLoadFailure)
                Positioned.fill(
                  child: _Banner(
                    icon: Icons.error_outline,
                    title: state.message,
                  ),
                )
              else if (isEmpty)
                Positioned.fill(
                  child: _Banner(
                    icon: Icons.place_outlined,
                    title: AppStrings.tr(locale, AppStrings.noArtifactsYet),
                    subtitle: AppStrings.tr(locale, AppStrings.noArtifactsHint),
                  ),
                ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        _CircleButton(
                          icon: Icons.arrow_back,
                          onTap: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: _TitlePill(
                            label:
                                widget.title ??
                                AppStrings.tr(locale, AppStrings.artifactsMap),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (unlocatedCount > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24,
                  child: Center(
                    child: _UnlocatedChip(
                      count: unlocatedCount,
                      label: AppStrings.tr(locale, AppStrings.withoutLocation),
                      onTap: () => UnlocatedArtifactsSheet.show(
                        context,
                        repository: widget.repository,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Shown when the app was built without a Mapbox token, instead of a blank
/// canvas that looks like a bug.
class _MapUnavailable extends StatelessWidget {
  const _MapUnavailable({required this.locale});

  final Locale locale;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          _Banner(
            icon: Icons.map_outlined,
            title: AppStrings.tr(locale, AppStrings.mapTokenMissing),
            subtitle: AppStrings.tr(locale, AppStrings.mapTokenMissingHint),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _CircleButton(
              icon: Icons.arrow_back,
              onTap: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IgnorePointer(
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'Inter',
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: theme.colorScheme.onSurface),
        ),
      ),
    );
  }
}

class _TitlePill extends StatelessWidget {
  const _TitlePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _UnlocatedChip extends StatelessWidget {
  const _UnlocatedChip({
    required this.count,
    required this.label,
    required this.onTap,
  });

  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      borderRadius: BorderRadius.circular(20),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_off_outlined,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '$count $label',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
