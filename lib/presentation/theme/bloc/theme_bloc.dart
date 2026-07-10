import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../domain/repositories/theme_repository.dart';

part 'theme_event.dart';
part 'theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc({required ThemeRepository repository})
      : _repository = repository,
        super(const ThemeState(ThemeMode.system)) {
    on<ThemeEvent>(
      (event, emit) => switch (event) {
        ThemeLoadRequested() => _onLoadRequested(event, emit),
        ThemeModeChanged() => _onModeChanged(event, emit),
      },
      transformer: sequential(),
    );
  }

  final ThemeRepository _repository;

  Future<void> _onLoadRequested(
    ThemeLoadRequested event,
    Emitter<ThemeState> emit,
  ) async {
    final mode = await _repository.loadThemeMode();
    emit(ThemeState(mode));
  }

  Future<void> _onModeChanged(
    ThemeModeChanged event,
    Emitter<ThemeState> emit,
  ) async {
    final mode = event.isDark ? ThemeMode.dark : ThemeMode.light;
    await _repository.saveThemeMode(mode);
    emit(ThemeState(mode));
  }
}
