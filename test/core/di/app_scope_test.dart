import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:archset_r2/core/dependencies.dart';
import 'package:archset_r2/core/di/app_scope.dart';
import 'package:archset_r2/core/logging/logger.dart';
import 'package:archset_r2/domain/repositories/auth_repository.dart';
import 'package:archset_r2/domain/repositories/locale_repository.dart';
import 'package:archset_r2/domain/repositories/theme_repository.dart';
import 'package:archset_r2/presentation/auth/auth_dependencies.dart';
import 'package:archset_r2/presentation/auth/bloc/auth_bloc.dart';
import 'package:archset_r2/presentation/core_deps/core_dependencies.dart';
import 'package:archset_r2/presentation/locale/bloc/locale_bloc.dart';
import 'package:archset_r2/presentation/locale/locale_dependencies.dart';
import 'package:archset_r2/presentation/theme/bloc/theme_bloc.dart';
import 'package:archset_r2/presentation/theme/theme_dependencies.dart';
import '../../support/fake_app_database.dart';

class _MockThemeRepository extends Mock implements ThemeRepository {}

class _MockLocaleRepository extends Mock implements LocaleRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late Dependencies dependencies;
  late _MockThemeRepository themeRepository;
  late _MockLocaleRepository localeRepository;

  setUp(() {
    themeRepository = _MockThemeRepository();
    when(() => themeRepository.loadThemeMode())
        .thenAnswer((_) async => ThemeMode.system);
    localeRepository = _MockLocaleRepository();
    when(() => localeRepository.loadLocale())
        .thenAnswer((_) async => const Locale('en'));

    dependencies = Dependencies(
      core: CoreDependencies(
        database: FakeAppDatabase(),
        secureStorage: const FlutterSecureStorage(),
        logger: Logger(),
      ),
      theme: ThemeDependencies(repository: themeRepository),
      locale: LocaleDependencies(repository: localeRepository),
      auth: AuthDependencies(repository: _MockAuthRepository()),
    );
  });

  testWidgets('exposes Dependencies and CoreDependencies to descendants',
      (tester) async {
    late BuildContext capturedContext;

    await tester.pumpWidget(AppScope(
      dependencies: dependencies,
      child: Builder(
        builder: (context) {
          capturedContext = context;
          return const SizedBox();
        },
      ),
    ));

    expect(capturedContext.di, same(dependencies));
    expect(capturedContext.coreDependencies, same(dependencies.core));
  });

  testWidgets('exposes ThemeBloc, LocaleBloc, and AuthBloc to descendants',
      (tester) async {
    late BuildContext capturedContext;

    await tester.pumpWidget(AppScope(
      dependencies: dependencies,
      child: Builder(
        builder: (context) {
          capturedContext = context;
          return const SizedBox();
        },
      ),
    ));

    expect(BlocProvider.of<ThemeBloc>(capturedContext), isA<ThemeBloc>());
    expect(BlocProvider.of<LocaleBloc>(capturedContext), isA<LocaleBloc>());
    expect(BlocProvider.of<AuthBloc>(capturedContext), isA<AuthBloc>());
  });

  testWidgets('ThemeBloc and LocaleBloc load their persisted values on creation',
      (tester) async {
    await tester.pumpWidget(AppScope(
      dependencies: dependencies,
      child: const SizedBox(),
    ));
    await tester.pump();

    verify(() => themeRepository.loadThemeMode()).called(1);
    verify(() => localeRepository.loadLocale()).called(1);
  });
}
