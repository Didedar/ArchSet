import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:archset_r2/domain/repositories/theme_repository.dart';
import 'package:archset_r2/presentation/theme/bloc/theme_bloc.dart';

class _MockThemeRepository extends Mock implements ThemeRepository {}

void main() {
  late _MockThemeRepository repository;

  setUpAll(() => registerFallbackValue(ThemeMode.system));

  setUp(() {
    repository = _MockThemeRepository();
  });

  blocTest<ThemeBloc, ThemeState>(
    'emits the persisted mode on ThemeLoadRequested',
    setUp: () => when(
      () => repository.loadThemeMode(),
    ).thenAnswer((_) async => ThemeMode.dark),
    build: () => ThemeBloc(repository: repository),
    act: (bloc) => bloc.add(const ThemeLoadRequested()),
    expect: () => [const ThemeState(ThemeMode.dark)],
  );

  blocTest<ThemeBloc, ThemeState>(
    'emits and persists the new mode on ThemeModeChanged',
    setUp: () =>
        when(() => repository.saveThemeMode(any())).thenAnswer((_) async {}),
    build: () => ThemeBloc(repository: repository),
    act: (bloc) => bloc.add(const ThemeModeChanged(true)),
    expect: () => [const ThemeState(ThemeMode.dark)],
    verify: (_) {
      verify(() => repository.saveThemeMode(ThemeMode.dark)).called(1);
    },
  );

  blocTest<ThemeBloc, ThemeState>(
    'ThemeModeChanged(false) selects light mode',
    setUp: () =>
        when(() => repository.saveThemeMode(any())).thenAnswer((_) async {}),
    build: () => ThemeBloc(repository: repository),
    act: (bloc) => bloc.add(const ThemeModeChanged(false)),
    expect: () => [const ThemeState(ThemeMode.light)],
  );

  test('initial state is ThemeMode.system', () {
    expect(
      ThemeBloc(repository: repository).state,
      const ThemeState(ThemeMode.system),
    );
  });
}
