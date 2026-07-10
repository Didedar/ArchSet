import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import '../../../data/services/whisper_service.dart';

part 'transcription_event.dart';
part 'transcription_state.dart';

class TranscriptionBloc extends Bloc<TranscriptionEvent, TranscriptionState> {
  TranscriptionBloc({required WhisperService whisperService})
      : _whisperService = whisperService,
        super(const TranscriptionState()) {
    on<TranscriptionModelStatusChecked>(_onModelStatusChecked);
    on<TranscriptionEngineChanged>(_onEngineChanged);
    on<TranscriptionModelDownloadRequested>(
      _onModelDownloadRequested,
      transformer: droppable(),
    );
  }

  final WhisperService _whisperService;

  Future<void> _onModelStatusChecked(
    TranscriptionModelStatusChecked event,
    Emitter<TranscriptionState> emit,
  ) async {
    final downloaded = await _whisperService.isModelDownloaded();
    emit(state.copyWith(isModelDownloaded: downloaded));
  }

  void _onEngineChanged(
    TranscriptionEngineChanged event,
    Emitter<TranscriptionState> emit,
  ) {
    emit(state.copyWith(engine: event.engine));
  }

  Future<void> _onModelDownloadRequested(
    TranscriptionModelDownloadRequested event,
    Emitter<TranscriptionState> emit,
  ) async {
    emit(state.copyWith(isDownloading: true, downloadProgress: 0.0));
    try {
      await _whisperService.downloadModel(
        onProgress: (progress) {
          emit(state.copyWith(downloadProgress: progress));
        },
      );
      emit(
        state.copyWith(
          isDownloading: false,
          isModelDownloaded: true,
          downloadProgress: 1.0,
        ),
      );
      await _whisperService.init();
    } catch (e) {
      emit(state.copyWith(isDownloading: false, downloadProgress: 0.0));
      rethrow;
    }
  }
}
