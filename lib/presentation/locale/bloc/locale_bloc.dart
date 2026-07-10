import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../domain/repositories/locale_repository.dart';

part 'locale_event.dart';
part 'locale_state.dart';

class LocaleBloc extends Bloc<LocaleEvent, LocaleState> {
  LocaleBloc({required LocaleRepository repository})
      : _repository = repository,
        super(const LocaleState(Locale('en'))) {
    on<LocaleEvent>(
      (event, emit) => switch (event) {
        LocaleLoadRequested() => _onLoadRequested(event, emit),
        LocaleChanged() => _onChanged(event, emit),
      },
      transformer: sequential(),
    );
  }

  final LocaleRepository _repository;

  Future<void> _onLoadRequested(
    LocaleLoadRequested event,
    Emitter<LocaleState> emit,
  ) async {
    final locale = await _repository.loadLocale();
    emit(LocaleState(locale));
  }

  Future<void> _onChanged(
    LocaleChanged event,
    Emitter<LocaleState> emit,
  ) async {
    await _repository.saveLocale(event.languageCode);
    emit(LocaleState(Locale(event.languageCode)));
  }
}
