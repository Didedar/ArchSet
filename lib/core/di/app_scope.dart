import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import '../dependencies.dart';
import '../../presentation/audio/bloc/audio_bloc.dart';
import '../../presentation/auth/bloc/auth_bloc.dart';
import '../../presentation/core_deps/core_dependencies.dart';
import '../../presentation/editor/bloc/editor_bloc.dart';
import '../../presentation/locale/bloc/locale_bloc.dart';
import '../../presentation/notes/bloc/folders_bloc.dart';
import '../../presentation/notes/bloc/notes_bloc.dart';
import '../../presentation/session/bloc/session_cubit.dart';
import '../../presentation/sync/bloc/sync_bloc.dart';
import '../../presentation/theme/bloc/theme_bloc.dart';
import '../../presentation/transcription/bloc/transcription_bloc.dart';

/// The DI boundary. Exposes [Dependencies]/[CoreDependencies] via
/// `package:provider`, and every global BLoC via [MultiBlocProvider].
class AppScope extends StatelessWidget {
  const AppScope({required this.dependencies, required this.child, super.key});

  final Dependencies dependencies;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Dependencies>.value(value: dependencies),
        Provider<CoreDependencies>.value(value: dependencies.core),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ThemeBloc>(
            lazy: false,
            create: (_) =>
                ThemeBloc(repository: dependencies.theme.repository)
                  ..add(const ThemeLoadRequested()),
          ),
          BlocProvider<LocaleBloc>(
            lazy: false,
            create: (_) =>
                LocaleBloc(repository: dependencies.locale.repository)
                  ..add(const LocaleLoadRequested()),
          ),
          BlocProvider<AuthBloc>(
            create: (_) => AuthBloc(repository: dependencies.auth.repository),
          ),
          // Eager + bootstrapped immediately: this is what SessionGate (the
          // app's root screen) renders off of, so it must have resolved (or
          // at least started resolving) the stored session before the first
          // frame. `dependencies.auth.repository` is the concrete
          // AuthService (see AuthDependencies), which is both an
          // AuthRepository and the source of onSessionExpired.
          BlocProvider<SessionCubit>(
            lazy: false,
            create: (_) => SessionCubit(
              repository: dependencies.auth.repository,
              sessionExpiredSignal:
                  dependencies.auth.repository.onSessionExpired,
            )..bootstrap(),
          ),
          BlocProvider<SyncBloc>(
            lazy: false,
            create: (_) =>
                SyncBloc(service: dependencies.sync.service)
                  ..add(const SyncMonitoringStarted()),
          ),
          // Notes/Folders stay lazy (default): unlike Theme/Locale/Sync,
          // nothing needs to happen before a notes-related page actually
          // mounts and requests data.
          BlocProvider<NotesBloc>(
            create: (_) => NotesBloc(repository: dependencies.notes.repository),
          ),
          BlocProvider<FoldersBloc>(
            create: (_) =>
                FoldersBloc(repository: dependencies.notes.repository),
          ),
          // Eager: AudioBloc's stop-recording flow reads TranscriptionBloc's
          // state via the widget (never directly), so the model-downloaded
          // check needs to have already run by the time recording can
          // start, not just after a prior visit to Settings.
          BlocProvider<TranscriptionBloc>(
            lazy: false,
            create: (_) => TranscriptionBloc(
              whisperService: dependencies.transcription.whisperService,
            )..add(const TranscriptionModelStatusChecked()),
          ),
          // Audio/Editor stay lazy: nothing needs to happen before the
          // diary editor page actually mounts.
          BlocProvider<AudioBloc>(
            create: (_) => AudioBloc(
              audioService: dependencies.audio.audioService,
              geminiService: dependencies.audio.geminiService,
              whisperService: dependencies.audio.whisperService,
            ),
          ),
          BlocProvider<EditorBloc>(
            create: (_) => EditorBloc(
              notesRepository: dependencies.editor.notesRepository,
              geminiService: dependencies.editor.geminiService,
              apiService: dependencies.editor.apiService,
            ),
          ),
        ],
        child: child,
      ),
    );
  }
}

extension AppScopeContext on BuildContext {
  Dependencies get di => read<Dependencies>();
  CoreDependencies get coreDependencies => read<CoreDependencies>();
}
