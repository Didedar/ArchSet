import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:archset_r2/core/localization/app_strings.dart';
import 'package:archset_r2/data/services/members_service.dart';
import 'package:archset_r2/presentation/locale/bloc/locale_bloc.dart';
import 'package:archset_r2/presentation/members/members_page.dart';

class _MockMembersService extends Mock implements MembersService {}

class _MockLocaleBloc extends MockBloc<LocaleEvent, LocaleState>
    implements LocaleBloc {}

/// Membership is the one part of collaboration that cannot work offline, and
/// the failures it produces are the ones a person actually has to act on. So
/// these tests are mostly about whether the reason reaches them in words they
/// can use, rather than as an HTTP status.
void main() {
  late _MockMembersService service;
  late _MockLocaleBloc localeBloc;

  const locale = Locale('en');
  String s(String key) => AppStrings.tr(locale, key);

  final member = DigSiteMember(
    userId: 'u2',
    email: 'maria@example.com',
    joinedAt: DateTime(2026, 8, 2),
  );

  setUp(() {
    service = _MockMembersService();
    when(() => service.listMembers(any())).thenAnswer((_) async => [member]);

    localeBloc = _MockLocaleBloc();
    whenListen(
      localeBloc,
      const Stream<LocaleState>.empty(),
      initialState: const LocaleState(locale),
    );
  });

  Future<void> pump(WidgetTester tester, {required bool isOwner}) async {
    await tester.pumpWidget(
      BlocProvider<LocaleBloc>.value(
        value: localeBloc,
        child: MaterialApp(
          home: MembersPage(
            folderId: 'f1',
            folderName: 'Раскоп 3',
            isOwner: isOwner,
            service: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists who the dig site is shared with', (tester) async {
    await pump(tester, isOwner: true);

    expect(find.text('maria@example.com'), findsOneWidget);
  });

  testWidgets('a member sees the roster but is offered no way to change it', (
    tester,
  ) async {
    await pump(tester, isOwner: false);

    expect(find.text('maria@example.com'), findsOneWidget);
    expect(find.text(s(AppStrings.inviteMember)), findsNothing);
    expect(find.text(s(AppStrings.removeMember)), findsNothing);
  });

  testWidgets('an unknown email is explained, not shown as a status code', (
    tester,
  ) async {
    when(
      () => service.invite(any(), any()),
    ).thenThrow(const InviteException(InviteFailure.unknownEmail));
    await pump(tester, isOwner: true);

    await tester.enterText(find.byType(TextField), 'nobody@example.com');
    await tester.tap(find.text(s(AppStrings.inviteMember)));
    await tester.pumpAndSettle();

    expect(find.text(s(AppStrings.inviteUnknownEmail)), findsOneWidget);
    expect(find.textContaining('404'), findsNothing);
  });

  testWidgets('an offline invitation says so instead of failing silently', (
    tester,
  ) async {
    when(
      () => service.invite(any(), any()),
    ).thenThrow(const InviteException(InviteFailure.offline));
    await pump(tester, isOwner: true);

    await tester.enterText(find.byType(TextField), 'maria@example.com');
    await tester.tap(find.text(s(AppStrings.inviteMember)));
    await tester.pumpAndSettle();

    expect(find.text(s(AppStrings.inviteOffline)), findsOneWidget);
  });

  testWidgets('a successful invitation clears the field and reloads', (
    tester,
  ) async {
    when(() => service.invite(any(), any())).thenAnswer((_) async => member);
    await pump(tester, isOwner: true);

    await tester.enterText(find.byType(TextField), 'maria@example.com');
    await tester.tap(find.text(s(AppStrings.inviteMember)));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    verify(() => service.listMembers('f1')).called(2);
  });

  testWidgets('removing a member calls revoke with their id', (tester) async {
    when(() => service.revoke(any(), any())).thenAnswer((_) async {});
    await pump(tester, isOwner: true);

    await tester.tap(find.text(s(AppStrings.removeMember)));
    await tester.pumpAndSettle();

    verify(() => service.revoke('f1', 'u2')).called(1);
  });
}
