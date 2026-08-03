import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:archset_r2/core/localization/app_strings.dart';
import 'package:archset_r2/data/database/app_database.dart';
import 'package:archset_r2/presentation/locale/bloc/locale_bloc.dart';
import 'package:archset_r2/presentation/widgets/folder_card.dart';
import 'package:archset_r2/presentation/widgets/note_card.dart';

class _MockLocaleBloc extends MockBloc<LocaleEvent, LocaleState>
    implements LocaleBloc {}

/// Sharing is only useful if you can tell whose work you are looking at.
/// Two archaeologists' entries rendering identically would be worse than not
/// sharing at all -- it turns a collaboration into an unattributed pile.
void main() {
  late _MockLocaleBloc localeBloc;
  const locale = Locale('en');

  setUp(() {
    localeBloc = _MockLocaleBloc();
    whenListen(
      localeBloc,
      const Stream<LocaleState>.empty(),
      initialState: const LocaleState(locale),
    );
  });

  Note note({String? authorId}) => Note(
    id: 'n1',
    title: 'Слой 2',
    content: 'Керамика',
    date: DateTime(2026, 8, 2),
    isDeleted: false,
    pendingSync: false,
    authorId: authorId,
  );

  Folder folder({required bool isShared}) => Folder(
    id: 'f1',
    name: 'Раскоп 3',
    color: '#E8B731',
    createdAt: DateTime(2026, 8, 2),
    isDeleted: false,
    pendingSync: false,
    isShared: isShared,
  );

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      BlocProvider<LocaleBloc>.value(
        value: localeBloc,
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('NoteCard authorship', () {
    testWidgets("names the author when a colleague wrote it", (tester) async {
      await pump(
        tester,
        NoteCard(
          note: note(authorId: 'maria'),
          index: 0,
          onTap: () {},
          currentOwnerId: 'ivan',
        ),
      );

      expect(find.textContaining('maria'), findsOneWidget);
    });

    testWidgets('stays quiet about authorship on your own note', (
      tester,
    ) async {
      await pump(
        tester,
        NoteCard(
          note: note(authorId: 'ivan'),
          index: 0,
          onTap: () {},
          currentOwnerId: 'ivan',
        ),
      );

      expect(
        find.textContaining(AppStrings.tr(locale, AppStrings.authorLabel)),
        findsNothing,
        reason: 'labelling every one of your own notes is noise',
      );
    });

    testWidgets('stays quiet when authorship was never recorded', (
      tester,
    ) async {
      // Rows that predate v11 have authorId == null. Showing "author: null"
      // would be worse than showing nothing.
      await pump(
        tester,
        NoteCard(note: note(), index: 0, onTap: () {}, currentOwnerId: 'ivan'),
      );

      expect(find.textContaining('null'), findsNothing);
      expect(
        find.textContaining(AppStrings.tr(locale, AppStrings.authorLabel)),
        findsNothing,
      );
    });
  });

  group('FolderCard sharing badge', () {
    testWidgets('marks a shared dig site', (tester) async {
      await pump(
        tester,
        FolderCard(
          folder: folder(isShared: true),
          noteCount: 3,
          onTap: () {},
          index: 0,
        ),
      );

      expect(find.byIcon(Icons.group_outlined), findsOneWidget);
    });

    testWidgets('leaves a private one unmarked', (tester) async {
      await pump(
        tester,
        FolderCard(
          folder: folder(isShared: false),
          noteCount: 3,
          onTap: () {},
          index: 0,
        ),
      );

      expect(find.byIcon(Icons.group_outlined), findsNothing);
    });
  });
}
