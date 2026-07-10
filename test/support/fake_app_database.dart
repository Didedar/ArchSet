import 'package:mocktail/mocktail.dart';
import 'package:archset_r2/data/database/app_database.dart';

/// A side-effect-free stand-in for [AppDatabase] for tests that just need
/// *some* database reference, not real query behavior. `implements` (not
/// `extends`) means the real singleton constructor — and its lazy sqlite
/// connection — is never touched, which matters specifically in
/// `testWidgets` tests: the real connection schedules a Timer that trips
/// the test framework's "no pending timers after dispose" invariant.
class FakeAppDatabase extends Mock implements AppDatabase {}
