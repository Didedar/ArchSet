part of 'artifacts_map_bloc.dart';

sealed class ArtifactsMapEvent {
  const ArtifactsMapEvent();
}

final class ArtifactsMapSubscriptionRequested extends ArtifactsMapEvent {
  const ArtifactsMapSubscriptionRequested();
}

final class _ArtifactsUpdated extends ArtifactsMapEvent {
  const _ArtifactsUpdated(this.artifacts);

  final List<Artifact> artifacts;
}

final class _UnlocatedCountUpdated extends ArtifactsMapEvent {
  const _UnlocatedCountUpdated(this.count);

  final int count;
}

final class _ArtifactsFailed extends ArtifactsMapEvent {
  const _ArtifactsFailed(this.message);

  final String message;
}
