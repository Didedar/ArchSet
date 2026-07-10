import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:archset_r2/core/dependencies.dart';
import 'package:archset_r2/core/di/app_scope.dart';
import 'package:archset_r2/core/logging/logger.dart';
import 'package:archset_r2/data/services/auth_service.dart';
import 'package:archset_r2/data/services/sync_service.dart';
import 'package:archset_r2/domain/repositories/locale_repository.dart';
import 'package:archset_r2/domain/repositories/theme_repository.dart';
import 'package:archset_r2/data/repository/notes_repository.dart';
import 'package:archset_r2/presentation/auth/auth_dependencies.dart';
import 'package:archset_r2/presentation/auth/bloc/auth_bloc.dart';
import 'package:archset_r2/presentation/core_deps/core_dependencies.dart';
import 'package:archset_r2/presentation/locale/bloc/locale_bloc.dart';
import 'package:archset_r2/presentation/locale/locale_dependencies.dart';
import 'package:archset_r2/presentation/notes/bloc/folders_bloc.dart';
import 'package:archset_r2/presentation/notes/bloc/notes_bloc.dart';
import 'package:archset_r2/presentation/notes/notes_dependencies.dart';
import 'package:archset_r2/presentation/sync/bloc/sync_bloc.dart';
import 'package:archset_r2/presentation/sync/sync_dependencies.dart';
import 'package:archset_r2/presentation/theme/bloc/theme_bloc.dart';
import 'package:archset_r2/presentation/theme/theme_dependencies.dart';
import '../../support/fake_app_database.dart';

class _MockThemeRepository extends Mock implements ThemeRepository {}

class _MockLocaleRepository extends Mock implements LocaleRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _MockSyncService extends Mock implements SyncService {}

void main() {
  late Dependencies dependencies;
  late _MockThemeRepository themeRepository;
  late _MockLocaleRepository localeRepository;
  late _MockSyncService syncService;

  setUp(() {
    themeRepository = _MockThemeRepository();
    when(() => themeRepository.loadThemeMode())
        .thenAnswer((_) async => ThemeMode.system);
    localeRepository = _MockLocaleRepository();
    when(() => localeRepository.loadLocale())
        .thenAnswer((_) async => const Locale('en'));
    syncService = _MockSyncService();
    when(() => syncService.startMonitoring()).thenReturn(null);
    when(() => syncService.statusStream)
        .thenAnswer((_) => const Stream<SyncStatus>.empty());
    when(() => syncService.resultStream)
        .thenAnswer((_) => const Stream<SyncResult>.empty());

    final database = FakeAppDatabase();
    dependencies = Dependencies(
      core: CoreDependencies(
        database: database,
        secureStorage: const FlutterSecureStorage(),
        logger: Logger(),
      ),
      theme: ThemeDependencies(repository: themeRepository),
      locale: LocaleDependencies(repository: localeRepository),
      auth: AuthDependencies(repository: _MockAuthService()),
      sync: SyncDependencies(service: syncService),
      notes: NotesDependencies(repository: NotesRepository(database)),
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

  testWidgets(
      'exposes ThemeBloc, LocaleBloc, AuthBloc, and SyncBloc to descendants',
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
    expect(BlocProvider.of<SyncBloc>(capturedContext), isA<SyncBloc>());
    expect(BlocProvider.of<NotesBloc>(capturedContext), isA<NotesBloc>());
    expect(BlocProvider.of<FoldersBloc>(capturedContext), isA<FoldersBloc>());
  });

  testWidgets(
      'ThemeBloc, LocaleBloc, and SyncBloc start on creation (not lazily)',
      (tester) async {
    await tester.pumpWidget(AppScope(
      dependencies: dependencies,
      child: const SizedBox(),
    ));
    await tester.pump();

    verify(() => themeRepository.loadThemeMode()).called(1);
    verify(() => localeRepository.loadLocale()).called(1);
    verify(() => syncService.startMonitoring()).called(1);
  });
}
