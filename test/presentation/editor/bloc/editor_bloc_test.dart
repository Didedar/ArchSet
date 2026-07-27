import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:archset_r2/data/database/app_database.dart';
import 'package:archset_r2/data/repository/notes_repository.dart';
import 'package:archset_r2/data/services/api_service.dart';
import 'package:archset_r2/data/services/backend_gemini_service.dart';
import 'package:archset_r2/presentation/editor/bloc/editor_bloc.dart';

class _MockNotesRepository extends Mock implements NotesRepository {}

class _MockBackendGeminiService extends Mock implements BackendGeminiService {}

class _MockApiService extends Mock implements ApiService {}

void main() {
  late _MockNotesRepository notesRepository;
  late _MockBackendGeminiService geminiService;
  late _MockApiService apiService;

  setUpAll(() {
    registerFallbackValue(
      Note(
        id: 'fallback',
        title: '',
        content: '',
        date: DateTime(2026, 1, 1),
        isDeleted: false,
        pendingSync: false,
      ),
    );
  });

  setUp(() {
    notesRepository = _MockNotesRepository();
    geminiService = _MockBackendGeminiService();
    apiService = _MockApiService();
  });

  EditorBloc buildBloc() => EditorBloc(
        notesRepository: notesRepository,
        geminiService: geminiService,
        apiService: apiService,
      );

  group('save', () {
    blocTest<EditorBloc, EditorState>(
      'persists a note with non-empty content',
      setUp: () =>
          when(() => notesRepository.insertNote(any())).thenAnswer((_) async {}),
      build: buildBloc,
      act: (bloc) => bloc.add(
        const EditorSaveRequested(
          noteId: 'n1',
          title: 'Title',
          contentJson: '{"ops":[]}',
          plainText: 'Some body text',
          folderId: 'f1',
          audioPath: '/tmp/a.m4a',
        ),
      ),
      expect: () => [
        const EditorSaveInProgress(),
        const EditorSaveSuccess(),
      ],
      verify: (_) {
        final captured =
            verify(() => notesRepository.insertNote(captureAny())).captured;
        final note = captured.single as Note;
        expect(note.id, 'n1');
        expect(note.title, 'Title');
        expect(note.content, '{"ops":[]}');
        expect(note.folderId, 'f1');
        expect(note.audioPath, '/tmp/a.m4a');
      },
    );

    blocTest<EditorBloc, EditorState>(
      'skips persistence when both title and content are empty',
      build: buildBloc,
      act: (bloc) => bloc.add(
        const EditorSaveRequested(
          noteId: 'n1',
          title: '',
          contentJson: '{"ops":[]}',
          plainText: '',
          folderId: null,
          audioPath: null,
        ),
      ),
      expect: () => [
        const EditorSaveInProgress(),
        const EditorSaveSuccess(),
      ],
      verify: (_) => verifyNever(() => notesRepository.insertNote(any())),
    );
  });

  group('delete', () {
    blocTest<EditorBloc, EditorState>(
      'hard-deletes locally when the backend confirms deletion',
      setUp: () {
        when(() => apiService.delete(any())).thenAnswer((_) async {});
        when(() => notesRepository.hardDeleteNote(any()))
            .thenAnswer((_) async {});
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const EditorDeleteRequested('n1')),
      expect: () => [
        const EditorDeleteInProgress(),
        const EditorDeleteSuccess(),
      ],
      verify: (_) {
        verify(() => apiService.delete('/notes/n1?hard_delete=true')).called(1);
        verify(() => notesRepository.hardDeleteNote('n1')).called(1);
        verifyNever(() => notesRepository.deleteNote(any()));
      },
    );

    blocTest<EditorBloc, EditorState>(
      'falls back to a local soft delete when the backend call fails',
      setUp: () {
        when(() => apiService.delete(any()))
            .thenThrow(Exception('offline'));
        when(() => notesRepository.deleteNote(any())).thenAnswer((_) async {});
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const EditorDeleteRequested('n1')),
      expect: () => [
        const EditorDeleteInProgress(),
        const EditorDeleteSuccess(),
      ],
      verify: (_) {
        verify(() => notesRepository.deleteNote('n1')).called(1);
        verifyNever(() => notesRepository.hardDeleteNote(any()));
      },
    );
  });

  group('AI rewrite', () {
    blocTest<EditorBloc, EditorState>(
      'emits the rewritten text on success',
      setUp: () => when(() => geminiService.rewriteForArchaeology(any()))
          .thenAnswer((_) async => 'rewritten'),
      build: buildBloc,
      act: (bloc) => bloc.add(const EditorAiRewriteRequested('original')),
      expect: () => [
        const EditorAiRewriteInProgress(),
        const EditorAiRewriteSuccess('rewritten'),
      ],
    );

    blocTest<EditorBloc, EditorState>(
      'emits a silent-message failure when the service returns nothing',
      setUp: () => when(() => geminiService.rewriteForArchaeology(any()))
          .thenAnswer((_) async => null),
      build: buildBloc,
      act: (bloc) => bloc.add(const EditorAiRewriteRequested('original')),
      expect: () => [
        const EditorAiRewriteInProgress(),
        const EditorAiRewriteFailure(),
      ],
    );

    blocTest<EditorBloc, EditorState>(
      'emits a failure carrying the exception message on error',
      setUp: () => when(() => geminiService.rewriteForArchaeology(any()))
          .thenThrow(Exception('network down')),
      build: buildBloc,
      act: (bloc) => bloc.add(const EditorAiRewriteRequested('original')),
      expect: () => [
        const EditorAiRewriteInProgress(),
        isA<EditorAiRewriteFailure>().having(
          (s) => s.exceptionMessage,
          'exceptionMessage',
          contains('network down'),
        ),
      ],
    );
  });

  group('image scan', () {
    blocTest<EditorBloc, EditorState>(
      'emits extracted text on success',
      setUp: () => when(() => geminiService.extractTextFromImage(any()))
          .thenAnswer((_) async => 'scanned text'),
      build: buildBloc,
      act: (bloc) => bloc.add(const EditorImageScanRequested('/tmp/img.png')),
      expect: () => [
        const EditorScanInProgress(),
        const EditorScanSuccess('scanned text'),
      ],
    );

    blocTest<EditorBloc, EditorState>(
      'emits a user-visible failure when nothing was extracted',
      setUp: () => when(() => geminiService.extractTextFromImage(any()))
          .thenAnswer((_) async => null),
      build: buildBloc,
      act: (bloc) => bloc.add(const EditorImageScanRequested('/tmp/img.png')),
      expect: () => [
        const EditorScanInProgress(),
        const EditorScanFailure(message: 'Failed to extract text'),
      ],
    );

    blocTest<EditorBloc, EditorState>(
      'emits a silent failure (no message) on exception',
      setUp: () => when(() => geminiService.extractTextFromImage(any()))
          .thenThrow(Exception('boom')),
      build: buildBloc,
      act: (bloc) => bloc.add(const EditorImageScanRequested('/tmp/img.png')),
      expect: () => [
        const EditorScanInProgress(),
        const EditorScanFailure(),
      ],
    );
  });

  test('initial state is EditorIdle', () {
    expect(buildBloc().state, const EditorIdle());
  });
}
