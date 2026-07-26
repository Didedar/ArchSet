import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/artifact.dart';
import '../../../data/repository/artifacts_repository.dart';

part 'artifacts_map_event.dart';
part 'artifacts_map_state.dart';

/// Feeds the artifacts map: located artifacts (the pins) plus a count of
/// photos that have no GPS fix, so the map can say so instead of silently
/// dropping them.
class ArtifactsMapBloc extends Bloc<ArtifactsMapEvent, ArtifactsMapState> {
  ArtifactsMapBloc({required ArtifactsRepository repository})
    : _repository = repository,
      super(const ArtifactsMapInitial()) {
    on<ArtifactsMapSubscriptionRequested>(
      _onSubscriptionRequested,
      transformer: restartable(),
    );
    on<_ArtifactsUpdated>(_onArtifactsUpdated, transformer: sequential());
    on<_UnlocatedCountUpdated>(
      _onUnlocatedCountUpdated,
      transformer: sequential(),
    );
    on<_ArtifactsFailed>(_onFailed, transformer: sequential());
  }

  final ArtifactsRepository _repository;
  StreamSubscription<List<Artifact>>? _artifactsSub;
  StreamSubscription<int>? _unlocatedSub;

  Future<void> _onSubscriptionRequested(
    ArtifactsMapSubscriptionRequested event,
    Emitter<ArtifactsMapState> emit,
  ) async {
    emit(const ArtifactsMapLoadInProgress());
    await _artifactsSub?.cancel();
    await _unlocatedSub?.cancel();

    _artifactsSub = _repository.watchLocatedArtifacts().listen(
      (artifacts) => add(_ArtifactsUpdated(artifacts)),
      onError: (Object error) => add(_ArtifactsFailed(error.toString())),
    );
    _unlocatedSub = _repository.watchUnlocatedCount().listen(
      (count) => add(_UnlocatedCountUpdated(count)),
      onError: (Object error) => add(_ArtifactsFailed(error.toString())),
    );
  }

  void _onArtifactsUpdated(
    _ArtifactsUpdated event,
    Emitter<ArtifactsMapState> emit,
  ) {
    emit(_currentSuccess.copyWith(artifacts: event.artifacts));
  }

  void _onUnlocatedCountUpdated(
    _UnlocatedCountUpdated event,
    Emitter<ArtifactsMapState> emit,
  ) {
    emit(_currentSuccess.copyWith(unlocatedCount: event.count));
  }

  void _onFailed(_ArtifactsFailed event, Emitter<ArtifactsMapState> emit) {
    emit(ArtifactsMapLoadFailure(event.message));
  }

  ArtifactsMapLoadSuccess get _currentSuccess {
    final current = state;
    return current is ArtifactsMapLoadSuccess
        ? current
        : const ArtifactsMapLoadSuccess();
  }

  @override
  Future<void> close() async {
    await _artifactsSub?.cancel();
    await _unlocatedSub?.cancel();
    return super.close();
  }
}
