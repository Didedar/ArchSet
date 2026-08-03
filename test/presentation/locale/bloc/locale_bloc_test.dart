import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:archset_r2/domain/repositories/locale_repository.dart';
import 'package:archset_r2/presentation/locale/bloc/locale_bloc.dart';

class _MockLocaleRepository extends Mock implements LocaleRepository {}

void main() {
  late _MockLocaleRepository repository;

  setUp(() {
    repository = _MockLocaleRepository();
  });

  blocTest<LocaleBloc, LocaleState>(
    'emits the persisted locale on LocaleLoadRequested',
    setUp: () => when(
      () => repository.loadLocale(),
    ).thenAnswer((_) async => const Locale('ru')),
    build: () => LocaleBloc(repository: repository),
    act: (bloc) => bloc.add(const LocaleLoadRequested()),
    expect: () => [const LocaleState(Locale('ru'))],
  );

  blocTest<LocaleBloc, LocaleState>(
    'emits and persists the new locale on LocaleChanged',
    setUp: () =>
        when(() => repository.saveLocale(any())).thenAnswer((_) async {}),
    build: () => LocaleBloc(repository: repository),
    act: (bloc) => bloc.add(const LocaleChanged('kk')),
    expect: () => [const LocaleState(Locale('kk'))],
    verify: (_) {
      verify(() => repository.saveLocale('kk')).called(1);
    },
  );

  test('initial state is English', () {
    expect(
      LocaleBloc(repository: repository).state,
      const LocaleState(Locale('en')),
    );
  });
}
