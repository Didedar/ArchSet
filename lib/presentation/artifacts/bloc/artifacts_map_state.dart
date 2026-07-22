part of 'artifacts_map_bloc.dart';

sealed class ArtifactsMapState extends Equatable {
  const ArtifactsMapState();

  @override
  List<Object?> get props => [];
}

final class ArtifactsMapInitial extends ArtifactsMapState {
  const ArtifactsMapInitial();
}

final class ArtifactsMapLoadInProgress extends ArtifactsMapState {
  const ArtifactsMapLoadInProgress();
}

final class ArtifactsMapLoadSuccess extends ArtifactsMapState {
  const ArtifactsMapLoadSuccess({
    this.artifacts = const [],
    this.unlocatedCount = 0,
  });

  /// Artifacts with coordinates, newest first.
  final List<Artifact> artifacts;

  /// Photos that exist but have no GPS fix and so cannot be pinned.
  final int unlocatedCount;

  bool get isEmpty => artifacts.isEmpty;

  ArtifactsMapLoadSuccess copyWith({
    List<Artifact>? artifacts,
    int? unlocatedCount,
  }) {
    return ArtifactsMapLoadSuccess(
      artifacts: artifacts ?? this.artifacts,
      unlocatedCount: unlocatedCount ?? this.unlocatedCount,
    );
  }

  @override
  List<Object?> get props => [artifacts, unlocatedCount];
}

final class ArtifactsMapLoadFailure extends ArtifactsMapState {
  const ArtifactsMapLoadFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
