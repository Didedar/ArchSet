import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:archset_r2/core/dependencies.dart';
import 'package:archset_r2/core/di/app_scope.dart';
import 'package:archset_r2/core/logging/logger.dart';
import 'package:archset_r2/data/services/api_service.dart';
import 'package:archset_r2/data/services/auth_service.dart';
import 'package:archset_r2/data/services/backend_gemini_service.dart';
import 'package:archset_r2/data/services/members_service.dart';
import 'package:archset_r2/data/services/sync_service.dart';
import 'package:archset_r2/data/services/whisper_service.dart';
import 'package:archset_r2/domain/repositories/locale_repository.dart';
import 'package:archset_r2/domain/repositories/theme_repository.dart';
import 'package:archset_r2/domain/services/audio_service.dart';
import 'package:archset_r2/data/repository/notes_repository.dart';
import 'package:archset_r2/data/repository/artifacts_repository.dart';
import 'package:archset_r2/presentation/artifacts/artifacts_dependencies.dart';
import 'package:archset_r2/presentation/audio/audio_dependencies.dart';
import 'package:archset_r2/presentation/audio/bloc/audio_bloc.dart';
import 'package:archset_r2/presentation/auth/auth_dependencies.dart';
import 'package:archset_r2/presentation/auth/bloc/auth_bloc.dart';
import 'package:archset_r2/presentation/core_deps/core_dependencies.dart';
import 'package:archset_r2/presentation/editor/bloc/editor_bloc.dart';
import 'package:archset_r2/presentation/editor/editor_dependencies.dart';
import 'package:archset_r2/presentation/locale/bloc/locale_bloc.dart';
import 'package:archset_r2/presentation/locale/locale_dependencies.dart';
import 'package:archset_r2/presentation/notes/bloc/folders_bloc.dart';
import 'package:archset_r2/presentation/notes/bloc/notes_bloc.dart';
import 'package:archset_r2/presentation/notes/notes_dependencies.dart';
import 'package:archset_r2/presentation/session/bloc/session_cubit.dart';
import 'package:archset_r2/presentation/sync/bloc/sync_bloc.dart';
import 'package:archset_r2/presentation/sync/sync_dependencies.dart';
import 'package:archset_r2/presentation/theme/bloc/theme_bloc.dart';
import 'package:archset_r2/presentation/theme/theme_dependencies.dart';
import 'package:archset_r2/presentation/transcription/bloc/transcription_bloc.dart';
import 'package:archset_r2/presentation/transcription/transcription_dependencies.dart';
import '../../support/fake_app_database.dart';

class _MockThemeRepository extends Mock implements ThemeRepository {}

class _MockLocaleRepository extends Mock implements LocaleRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _MockSyncService extends Mock implements SyncService {}

class _MockWhisperService extends Mock implements WhisperService {}

class _MockAudioService extends Mock implements AudioService {}

class _MockBackendGeminiService extends Mock implements BackendGeminiService {}

class _MockApiServiceForScope extends Mock implements ApiService {}

void main() {
  late Dependencies dependencies;
  late _MockThemeRepository themeRepository;
  late _MockLocaleRepository localeRepository;
  late _MockAuthService authService;
  late _MockSyncService syncService;
  late _MockWhisperService whisperService;

  setUp(() {
    themeRepository = _MockThemeRepository();
    when(
      () => themeRepository.loadThemeMode(),
    ).thenAnswer((_) async => ThemeMode.system);
    localeRepository = _MockLocaleRepository();
    when(
      () => localeRepository.loadLocale(),
    ).thenAnswer((_) async => const Locale('en'));
    authService = _MockAuthService();
    // SessionCubit is created eagerly (lazy: false) and bootstrapped
    // immediately, so both of these are read/called during AppScope's own
    // build -- unlike loadStoredUser()'s failure (caught inside
    // SessionCubit.bootstrap itself), an unstubbed onSessionExpired getter
    // would throw synchronously while building the provider tree.
    when(
      () => authService.onSessionExpired,
    ).thenAnswer((_) => const Stream<void>.empty());
    when(() => authService.loadStoredUser()).thenAnswer((_) async => null);
    syncService = _MockSyncService();
    when(() => syncService.startMonitoring()).thenReturn(null);
    when(
      () => syncService.statusStream,
    ).thenAnswer((_) => const Stream<SyncStatus>.empty());
    when(
      () => syncService.resultStream,
    ).thenAnswer((_) => const Stream<SyncResult>.empty());
    whisperService = _MockWhisperService();
    when(
      () => whisperService.isModelDownloaded(),
    ).thenAnswer((_) async => false);

    final database = FakeAppDatabase();
    final audioService = _MockAudioService();
    when(
      () => audioService.recordingDurationStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => audioService.playbackPositionStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => audioService.playbackDurationStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => audioService.amplitudeStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => audioService.playerStateStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => audioService.currentIndexStream,
    ).thenAnswer((_) => const Stream.empty());
    final geminiService = _MockBackendGeminiService();
    final apiService = _MockApiServiceForScope();

    dependencies = Dependencies(
      core: CoreDependencies(
        database: database,
        secureStorage: const FlutterSecureStorage(),
        logger: Logger(),
      ),
      theme: ThemeDependencies(repository: themeRepository),
      locale: LocaleDependencies(repository: localeRepository),
      auth: AuthDependencies(repository: authService),
      sync: SyncDependencies(
        service: syncService,
        members: MembersService(ApiService(authService: authService)),
      ),
      notes: NotesDependencies(repository: NotesRepository(database)),
      transcription: TranscriptionDependencies(whisperService: whisperService),
      audio: AudioDependencies(
        audioService: audioService,
        geminiService: geminiService,
        whisperService: whisperService,
      ),
      editor: EditorDependencies(
        notesRepository: NotesRepository(database),
        geminiService: geminiService,
        apiService: apiService,
      ),
      artifacts: ArtifactsDependencies(
        repository: ArtifactsRepository(database),
      ),
    );
  });

  testWidgets('exposes Dependencies and CoreDependencies to descendants', (
    tester,
  ) async {
    late BuildContext capturedContext;

    await tester.pumpWidget(
      AppScope(
        dependencies: dependencies,
        child: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(capturedContext.di, same(dependencies));
    expect(capturedContext.coreDependencies, same(dependencies.core));
  });

  testWidgets(
    'exposes ThemeBloc, LocaleBloc, AuthBloc, and SyncBloc to descendants',
    (tester) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        AppScope(
          dependencies: dependencies,
          child: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(BlocProvider.of<ThemeBloc>(capturedContext), isA<ThemeBloc>());
      expect(BlocProvider.of<LocaleBloc>(capturedContext), isA<LocaleBloc>());
      expect(BlocProvider.of<AuthBloc>(capturedContext), isA<AuthBloc>());
      expect(
        BlocProvider.of<SessionCubit>(capturedContext),
        isA<SessionCubit>(),
      );
      expect(BlocProvider.of<SyncBloc>(capturedContext), isA<SyncBloc>());
      expect(BlocProvider.of<NotesBloc>(capturedContext), isA<NotesBloc>());
      expect(BlocProvider.of<FoldersBloc>(capturedContext), isA<FoldersBloc>());
      expect(
        BlocProvider.of<TranscriptionBloc>(capturedContext),
        isA<TranscriptionBloc>(),
      );
      expect(BlocProvider.of<AudioBloc>(capturedContext), isA<AudioBloc>());
      expect(BlocProvider.of<EditorBloc>(capturedContext), isA<EditorBloc>());
    },
  );

  testWidgets(
    'ThemeBloc, LocaleBloc, SessionCubit, SyncBloc, and TranscriptionBloc '
    'start on creation (not lazily)',
    (tester) async {
      await tester.pumpWidget(
        AppScope(dependencies: dependencies, child: const SizedBox()),
      );
      await tester.pump();

      verify(() => themeRepository.loadThemeMode()).called(1);
      verify(() => localeRepository.loadLocale()).called(1);
      verify(() => authService.loadStoredUser()).called(1);
      verify(() => syncService.startMonitoring()).called(1);
      verify(() => whisperService.isModelDownloaded()).called(1);
    },
  );
}
