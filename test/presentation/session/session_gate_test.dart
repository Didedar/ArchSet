import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/data/services/auth_service.dart';
import 'package:archset_r2/presentation/auth/pages/splash_page.dart';
import 'package:archset_r2/presentation/auth/pages/welcome_page.dart';
import 'package:archset_r2/presentation/notes/pages/notes_page.dart';
import 'package:archset_r2/presentation/session/bloc/session_cubit.dart';
import 'package:archset_r2/presentation/session/session_gate.dart';

void main() {
  final user = AuthUser(id: '1', email: 'a@b.com', createdAt: DateTime(2026));

  test('SessionUnknown maps to SplashPage', () {
    expect(SessionGate.screenFor(const SessionUnknown()), isA<SplashPage>());
  });

  test('SessionGuest maps to NotesPage', () {
    expect(SessionGate.screenFor(const SessionGuest()), isA<NotesPage>());
  });

  test('SessionAuthenticated maps to NotesPage', () {
    expect(SessionGate.screenFor(SessionAuthenticated(user)), isA<NotesPage>());
  });

  test('SessionUnauthenticated maps to WelcomePage', () {
    expect(
      SessionGate.screenFor(const SessionUnauthenticated()),
      isA<WelcomePage>(),
    );
  });
}
