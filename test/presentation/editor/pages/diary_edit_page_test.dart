import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:archset_r2/presentation/audio/bloc/audio_bloc.dart';
import 'package:archset_r2/presentation/editor/bloc/editor_bloc.dart';
import 'package:archset_r2/presentation/editor/pages/diary_edit_page.dart';
import 'package:archset_r2/presentation/locale/bloc/locale_bloc.dart';
import 'package:archset_r2/presentation/transcription/bloc/transcription_bloc.dart';

class _MockEditorBloc extends MockBloc<EditorEvent, EditorState>
    implements EditorBloc {}

class _MockAudioBloc extends MockBloc<AudioEvent, AudioState>
    implements AudioBloc {}

class _MockLocaleBloc extends MockBloc<LocaleEvent, LocaleState>
    implements LocaleBloc {}

class _MockTranscriptionBloc
    extends MockBloc<TranscriptionEvent, TranscriptionState>
    implements TranscriptionBloc {}

void main() {
  late _MockEditorBloc editorBloc;
  late _MockAudioBloc audioBloc;
  late _MockLocaleBloc localeBloc;
  late _MockTranscriptionBloc transcriptionBloc;
  late StreamController<EditorState> editorStateController;

  setUpAll(() {
    // A concrete EditorEvent subtype is enough: mocktail's fallback lookup
    // matches by `is EditorEvent`, so any() / captureAny() calls typed at
    // the sealed base type resolve to this.
    registerFallbackValue(
      const EditorSaveRequested(
        noteId: 'fallback',
        title: '',
        contentJson: '{}',
        plainText: '',
        folderId: null,
        audioPath: null,
      ),
    );
  });

  setUp(() {
    editorStateController = StreamController<EditorState>.broadcast();
    editorBloc = _MockEditorBloc();
    whenListen(
      editorBloc,
      editorStateController.stream,
      initialState: const EditorIdle(),
    );

    audioBloc = _MockAudioBloc();
    whenListen(
      audioBloc,
      const Stream<AudioState>.empty(),
      // Carries an audio path so the page's save-on-exit path can be
      // proven to persist an audio-only recording, not just text.
      initialState: const AudioState(audioPath: '/tmp/a.m4a'),
    );

    localeBloc = _MockLocaleBloc();
    whenListen(
      localeBloc,
      const Stream<LocaleState>.empty(),
      initialState: const LocaleState(Locale('en')),
    );

    transcriptionBloc = _MockTranscriptionBloc();
    whenListen(
      transcriptionBloc,
      const Stream<TranscriptionState>.empty(),
      initialState: const TranscriptionState(),
    );
  });

  tearDown(() {
    editorStateController.close();
  });

  /// Pumps a launcher route and pushes [DiaryEditPage] on top of it, so
  /// that popping the editor is observable (the launcher's button
  /// reappears / DiaryEditPage disappears from the tree).
  Future<void> pumpAndOpenEditor(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<EditorBloc>.value(value: editorBloc),
          BlocProvider<AudioBloc>.value(value: audioBloc),
          BlocProvider<LocaleBloc>.value(value: localeBloc),
          BlocProvider<TranscriptionBloc>.value(value: transcriptionBloc),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DiaryEditPage(noteId: 'n1'),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryEditPage), findsOneWidget);
  }

  testWidgets(
    'system back dispatches a single save carrying the audio path, '
    'then pops once the save succeeds',
    (tester) async {
      await pumpAndOpenEditor(tester);

      // Simulate the Android system back gesture/button, not the chevron.
      await tester.binding.handlePopRoute();
      await tester.pump();

      final captured = verify(
        () => editorBloc.add(captureAny()),
      ).captured;
      expect(captured, hasLength(1));
      expect(captured.single, isA<EditorSaveRequested>());
      final event = captured.single as EditorSaveRequested;
      expect(event.audioPath, '/tmp/a.m4a');

      // Page must still be present: the save hasn't resolved yet, so a
      // hang here (the pre-A4 firstWhere-on-success-only bug) would show
      // up as this pump not completing rather than as a failed pop.
      expect(find.byType(DiaryEditPage), findsOneWidget);

      editorStateController.add(const EditorSaveSuccess());
      await tester.pumpAndSettle();

      expect(find.byType(DiaryEditPage), findsNothing);
    },
  );

  testWidgets(
    'a second system back while the first save is in flight does not '
    'dispatch a second save',
    (tester) async {
      await pumpAndOpenEditor(tester);

      await tester.binding.handlePopRoute(); // starts saving
      await tester.pump();
      await tester.binding.handlePopRoute(); // repeated back, still saving
      await tester.pump();

      verify(() => editorBloc.add(any())).called(1);

      // Let the in-flight save resolve so nothing leaks past the test.
      editorStateController.add(const EditorSaveSuccess());
      await tester.pumpAndSettle();
      expect(find.byType(DiaryEditPage), findsNothing);
    },
  );

  testWidgets(
    'a save failure keeps the editor open and surfaces a snackbar '
    'instead of hanging',
    (tester) async {
      await pumpAndOpenEditor(tester);

      await tester.binding.handlePopRoute();
      await tester.pump();

      editorStateController.add(
        const EditorSaveFailure(message: 'db locked'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiaryEditPage), findsOneWidget);
      expect(
        find.text('Save failed. Please try again.'),
        findsOneWidget,
      );
    },
  );
}
