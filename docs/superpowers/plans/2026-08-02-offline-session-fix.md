# Offline Session Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Пользователь с аккаунтом, запустивший приложение без сети, остаётся собой и видит свой дневник — вместо того чтобы молча стать гостем и увидеть пустой список.

**Architecture:** Единственное смысловое изменение — `AuthService.loadStoredUser()` при недоступном сервере возвращает закэшированную личность из secure storage вместо `null`. Всё остальное (`SessionCubit`, `CurrentOwnerHolder`, `NotesRepository`) уже работает правильно и не трогается: они просто получают верный ответ на входе. Отказ сервера (401) продолжает разлогинивать — меняется только ветка «не дозвонились».

**Tech Stack:** Flutter/Dart, `flutter_secure_storage`, `http` + `MockClient`, `drift` (in-memory для интеграционного теста), `flutter_test`.

**Спека:** `docs/superpowers/specs/2026-08-02-collaborative-dig-sites-design.md`, раздел 0.

---

## Контекст бага

`AuthService.loadStoredUser()` (`lib/data/services/auth_service.dart:285`) при
недоступном сервере возвращает `null`. `SessionCubit.bootstrap()` трактует `null`
как «пользователя нет» → `SessionGuest` → `CurrentOwnerHolder.value = null` →
`NotesRepository._ownerFilter` (`lib/data/repository/notes_repository.dart:23`)
показывает только строки с `ownerKey IS NULL`.

Итог: заметки пользователя целы в SQLite, но отфильтрованы. Дневник выглядит
пустым.

## Структура файлов

| Файл | Ответственность | Что меняется |
|---|---|---|
| `lib/data/services/auth_service.dart` | Аутентификация, хранение сессии | Ключ `userCreatedAt`, `_persistUser` пишет его, `login()` перестаёт дублировать запись, `_cachedUser()`, ветка `_MeUnreachable`, `_clearNamespacedSession` чистит новый ключ |
| `test/data/services/auth_service_test.dart` | Тесты AuthService | Существующий офлайн-тест переписывается под новое поведение, добавляются новые |
| `test/presentation/session/session_offline_test.dart` | **Создаётся.** Интеграция AuthService → SessionCubit → CurrentOwnerHolder → NotesRepository | Регрессия на всю цепочку бага + требование спеки №6 (разлогин не трогает заметки) |

Новый тест-файл отдельный, а не внутри `auth_service_test.dart`: он проверяет
не сервис, а стык четырёх слоёв, и тянет в зависимости базу и репозиторий.

---

## Task 1: Кэшировать `createdAt` вместе с сессией

`AuthUser` требует `createdAt`, а в secure storage лежат только `id` и `email`.
Чтобы восстановить пользователя офлайн, нужен третий ключ.

Заодно `login()` (строки ~211-223) дублирует запись тех же ключей, что и
`_persistUser`. Дубликат разъедется при первом же изменении — убираем.

**Files:**
- Modify: `lib/data/services/auth_service.dart`
- Test: `test/data/services/auth_service_test.dart`

- [ ] **Step 1: Написать падающий тест**

Добавить в `test/data/services/auth_service_test.dart` внутрь `void main()`,
в конец (перед закрывающей `}`):

```dart
  group('cached identity', () {
    const slug = 'archset_backend_production_up_railway_app_443';

    test('login persists createdAt alongside id and email', () async {
      final client = _clientFor(userId: 'u1', userEmail: 'u1@example.com');
      final service = _service(baseUrl: _prodBaseUrl, client: client);
      addTearDown(service.dispose);

      await service.login('u1@example.com', 'password');

      expect(
        storageValues[AuthStorageKeys.userCreatedAt(slug)],
        '2026-01-01T00:00:00.000Z',
      );
    });
  });
```

Примечание: `_clientFor` уже отдаёт `'created_at': '2026-01-01T00:00:00.000Z'`
(см. верх файла), поэтому ожидаемое значение именно такое.

- [ ] **Step 2: Убедиться, что тест падает**

Run:
```bash
flutter test test/data/services/auth_service_test.dart --plain-name "login persists createdAt"
```
Expected: FAIL — компиляция не проходит, `AuthStorageKeys.userCreatedAt` не определён.

- [ ] **Step 3: Добавить ключ хранения**

В `lib/data/services/auth_service.dart`, в классе `AuthStorageKeys`, после
`_userEmailStem`:

```dart
  static const String _userCreatedAtStem = 'user_created_at';
```

И после метода `userEmail`:

```dart
  static String userCreatedAt(String slug) => '${_userCreatedAtStem}_$slug';
```

- [ ] **Step 4: Писать `createdAt` в `_persistUser`**

Заменить тело `_persistUser` целиком:

```dart
  Future<void> _persistUser(AuthUser user) async {
    _currentUser = user;
    await Future.wait([
      _storage.write(key: AuthStorageKeys.userId(_originSlug), value: user.id),
      _storage.write(
        key: AuthStorageKeys.userEmail(_originSlug),
        value: user.email,
      ),
      _storage.write(
        key: AuthStorageKeys.userCreatedAt(_originSlug),
        value: user.createdAt.toIso8601String(),
      ),
      _storage.write(key: AuthStorageKeys.currentOwnerId, value: user.id),
    ]);
  }
```

- [ ] **Step 5: Убрать дублирование в `login()`**

В `login()` найти блок, начинающийся с `final user = AuthUser.fromJson(...)`
и заканчивающийся `return user;`, и заменить его на:

```dart
      final user = AuthUser.fromJson(jsonDecode(userResponse.body));
      await _persistUser(user);
      return user;
```

Это удаляет присваивание `_currentUser` и три `_storage.write` — всё то же
самое теперь делает `_persistUser`.

- [ ] **Step 6: Чистить новый ключ при разлогине**

В `_clearNamespacedSession()` добавить в список `Future.wait` после
`userEmail`:

```dart
      _storage.delete(key: AuthStorageKeys.userCreatedAt(_originSlug)),
```

- [ ] **Step 7: Прогнать тест**

Run:
```bash
flutter test test/data/services/auth_service_test.dart --concurrency=1
```
Expected: PASS, все тесты файла зелёные.

- [ ] **Step 8: Коммит**

```bash
git add lib/data/services/auth_service.dart test/data/services/auth_service_test.dart
git commit -m "refactor(auth): persist user createdAt and route login through _persistUser"
```

---

## Task 2: Возвращать закэшированного пользователя, когда сервер недоступен

Смысловая часть фикса.

**Files:**
- Modify: `lib/data/services/auth_service.dart`
- Test: `test/data/services/auth_service_test.dart`

- [ ] **Step 1: Переписать существующий тест под новое поведение**

В `test/data/services/auth_service_test.dart` найти тест
`'a network error (offline) returns null but preserves the stored access token'`
и **заменить его целиком** на:

```dart
    test('a network error (offline) returns the cached user and preserves the '
        'stored access token', () async {
      storageValues[AuthStorageKeys.accessToken(slug)] = 'still-good-token';
      storageValues[AuthStorageKeys.userId(slug)] = 'old-id';
      storageValues[AuthStorageKeys.userEmail(slug)] = 'old@example.com';
      storageValues[AuthStorageKeys.userCreatedAt(slug)] =
          '2026-01-01T00:00:00.000Z';

      final client = MockClient((request) async {
        throw const SocketException('offline');
      });
      final service = _service(baseUrl: _localBaseUrl, client: client);
      addTearDown(service.dispose);

      final user = await service.loadStoredUser();

      // "Couldn't verify" must not collapse into "no user": that is what made
      // an offline launch look like a guest session with an empty diary.
      expect(user, isNotNull);
      expect(user!.id, 'old-id');
      expect(user.email, 'old@example.com');
      expect(
        storageValues[AuthStorageKeys.accessToken(slug)],
        'still-good-token',
      );
    });

    test('a network error with no cached identity still returns null', () async {
      storageValues[AuthStorageKeys.accessToken(slug)] = 'still-good-token';

      final client = MockClient((request) async {
        throw const SocketException('offline');
      });
      final service = _service(baseUrl: _localBaseUrl, client: client);
      addTearDown(service.dispose);

      expect(await service.loadStoredUser(), isNull);
    });

    test('a session cached before createdAt was stored still loads', () async {
      storageValues[AuthStorageKeys.accessToken(slug)] = 'still-good-token';
      storageValues[AuthStorageKeys.userId(slug)] = 'legacy-id';
      storageValues[AuthStorageKeys.userEmail(slug)] = 'legacy@example.com';
      // No userCreatedAt key: this device signed in before Task 1 shipped.

      final client = MockClient((request) async {
        throw const SocketException('offline');
      });
      final service = _service(baseUrl: _localBaseUrl, client: client);
      addTearDown(service.dispose);

      final user = await service.loadStoredUser();

      expect(user?.id, 'legacy-id');
    });
```

- [ ] **Step 2: Убедиться, что тесты падают**

Run:
```bash
flutter test test/data/services/auth_service_test.dart --plain-name "offline" --concurrency=1
```
Expected: FAIL — `Expected: not null, Actual: <null>`.

- [ ] **Step 3: Добавить `_cachedUser()`**

В `lib/data/services/auth_service.dart`, сразу **после** метода `_persistUser`:

```dart
  /// The last verified identity for this backend origin, rebuilt from secure
  /// storage. Only used when the server could not be reached -- never to
  /// override an answer the server actually gave.
  Future<AuthUser?> _cachedUser() async {
    final id = await _storage.read(key: AuthStorageKeys.userId(_originSlug));
    final email = await _storage.read(
      key: AuthStorageKeys.userEmail(_originSlug),
    );
    if (id == null || email == null) return null;

    // Sessions stored before createdAt was persisted have no value here. The
    // app never reads createdAt, so epoch is a safe stand-in and is a better
    // outcome than forcing a field user to re-authenticate with no signal.
    final rawCreatedAt = await _storage.read(
      key: AuthStorageKeys.userCreatedAt(_originSlug),
    );
    final createdAt = rawCreatedAt == null
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : DateTime.tryParse(rawCreatedAt) ??
            DateTime.fromMillisecondsSinceEpoch(0);

    final user = AuthUser(id: id, email: email, createdAt: createdAt);
    _currentUser = user;
    return user;
  }
```

- [ ] **Step 4: Использовать его в ветке `_MeUnreachable`**

В `loadStoredUser()` заменить:

```dart
      case _MeUnreachable():
        return null; // keep token; unverified, not disproven
```

на:

```dart
      case _MeUnreachable():
        // "Couldn't verify" is not "verified and rejected". Returning null
        // here collapsed offline into guest: SessionCubit emitted
        // SessionGuest, CurrentOwnerHolder went null, and NotesRepository
        // filtered the user's own rows out -- an empty diary with no signal.
        // Keep the token AND the identity; the next successful contact
        // re-verifies, and a real 401 still logs out below.
        return _cachedUser();
```

- [ ] **Step 5: Прогнать тесты**

Run:
```bash
flutter test test/data/services/auth_service_test.dart --concurrency=1
```
Expected: PASS. Особенно должен остаться зелёным существующий тест про
разлогин при 401 + неудачном рефреше — он проверяет, что fail-closed не
сломан.

- [ ] **Step 6: Коммит**

```bash
git add lib/data/services/auth_service.dart test/data/services/auth_service_test.dart
git commit -m "fix(auth): keep the signed-in identity when the server is unreachable

An offline launch returned null from loadStoredUser(), which SessionCubit read
as 'no user' and turned into a guest session. That nulled CurrentOwnerHolder,
so NotesRepository filtered out every row owned by the account and the diary
looked empty with no network.

Unreachable now falls back to the cached identity. A rejected token (401 plus a
failed refresh) still clears the session."
```

---

## Task 3: Регрессионный тест на всю цепочку бага

Task 2 чинит сервис. Этот тест доказывает, что чинится **симптом** — видимость
заметок, — а не только возвращаемое значение одного метода.

**Files:**
- Create: `test/presentation/session/session_offline_test.dart`

- [ ] **Step 1: Написать падающий тест**

Создать `test/presentation/session/session_offline_test.dart`:

```dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'package:archset_r2/data/current_owner_holder.dart';
import 'package:archset_r2/data/database/app_database.dart';
import 'package:archset_r2/data/repository/notes_repository.dart';
import 'package:archset_r2/data/services/auth_service.dart';
import 'package:archset_r2/presentation/session/bloc/session_cubit.dart';

import '../../support/fake_secure_storage.dart';

/// Regression for the offline-launch bug: `loadStoredUser()` returned null
/// when the backend was unreachable, `SessionCubit` read that as a guest,
/// `CurrentOwnerHolder` went null, and `NotesRepository` then filtered out
/// every row owned by the account. The user saw an empty diary with their
/// data intact on disk.
///
/// This exercises the whole chain rather than any single layer, because every
/// layer in it was individually behaving as designed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const localBaseUrl = 'http://127.0.0.1:8000';
  const slug = '127_0_0_1_8000';

  late Map<String, String> storageValues;
  late AppDatabase database;

  setUp(() {
    storageValues = installFakeSecureStorage();
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  /// A backend that is simply not there, the way it is not there in a trench.
  AuthService offlineService() => AuthService(
    database: database,
    storage: const FlutterSecureStorage(),
    baseUrl: localBaseUrl,
    client: MockClient((request) async {
      throw const SocketException('offline');
    }),
  );

  void givenSignedInSession() {
    storageValues[AuthStorageKeys.accessToken(slug)] = 'token';
    storageValues[AuthStorageKeys.userId(slug)] = 'ivan';
    storageValues[AuthStorageKeys.userEmail(slug)] = 'ivan@example.com';
    storageValues[AuthStorageKeys.userCreatedAt(slug)] =
        '2026-01-01T00:00:00.000Z';
  }

  test('an offline launch keeps the account session instead of becoming a '
      'guest', () async {
    givenSignedInSession();
    final service = offlineService();
    addTearDown(service.dispose);
    final holder = CurrentOwnerHolder();
    final cubit = SessionCubit(repository: service, ownerHolder: holder);
    addTearDown(cubit.close);

    await cubit.bootstrap();

    expect(cubit.state, isA<SessionAuthenticated>());
    expect((cubit.state as SessionAuthenticated).user.id, 'ivan');
    expect(holder.value, 'ivan');
  });

  test('an offline launch still shows the notes the account owns', () async {
    givenSignedInSession();
    final service = offlineService();
    addTearDown(service.dispose);
    final holder = CurrentOwnerHolder();
    final repository = NotesRepository(database, ownerHolder: holder);
    final cubit = SessionCubit(repository: service, ownerHolder: holder);
    addTearDown(cubit.close);

    await database.into(database.notes).insert(
      NotesCompanion.insert(
        id: 'n1',
        title: 'Раскоп 3, слой 2',
        content: '',
        date: DateTime(2026, 8, 2),
        ownerKey: const Value('ivan'),
      ),
    );

    await cubit.bootstrap();

    final notes = await repository.watchAllNotes().first;
    expect(notes.map((n) => n.id), contains('n1'));
  });

  test('a genuine guest (no stored identity) still gets a guest session',
      () async {
    // No storage keys set at all.
    final service = offlineService();
    addTearDown(service.dispose);
    final holder = CurrentOwnerHolder();
    final cubit = SessionCubit(repository: service, ownerHolder: holder);
    addTearDown(cubit.close);

    await cubit.bootstrap();

    expect(cubit.state, isA<SessionGuest>());
    expect(holder.value, isNull);
  });

  /// Spec requirement 6. A refresh token can expire while the user is in the
  /// field for weeks; the forced logout that follows must clear the session
  /// and nothing else. Asserted rather than inferred from the method name.
  test('a forced logout (rejected token, failed refresh) clears the session '
      'but leaves unsynced notes on the device', () async {
    givenSignedInSession();
    await database.into(database.notes).insert(
      NotesCompanion.insert(
        id: 'n-dirty',
        title: 'Слой 3, не отправлено',
        content: '',
        date: DateTime(2026, 8, 2),
        ownerKey: const Value('ivan'),
        pendingSync: const Value(true),
      ),
    );

    // Server is reachable and says the token is dead; the refresh dies too.
    final service = AuthService(
      database: database,
      storage: const FlutterSecureStorage(),
      baseUrl: localBaseUrl,
      client: MockClient((request) async => http.Response('{}', 401)),
    );
    addTearDown(service.dispose);

    expect(await service.loadStoredUser(), isNull);
    expect(storageValues[AuthStorageKeys.accessToken(slug)], isNull);

    final rows = await database.select(database.notes).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, 'n-dirty');
    expect(rows.single.pendingSync, isTrue);
  });
}
```

Для этого теста нужен ещё один импорт в шапке файла:

```dart
import 'package:http/http.dart' as http;
```

- [ ] **Step 2: Добавить импорт `Value`**

`NotesCompanion.insert` выше использует `Value('ivan')`, поэтому в шапку теста
нужен импорт (именно с `show`, иначе drift-овский `isNull` перекроет матчер
`flutter_test` с тем же именем — так сделано и в
`test/data/repository/artifacts_repository_test.dart`):

```dart
import 'package:drift/drift.dart' show Value;
```

- [ ] **Step 3: Прогнать тест**

Run:
```bash
flutter test test/presentation/session/session_offline_test.dart --concurrency=1
```
Expected: PASS — Task 2 уже починил поведение, этот тест закрепляет симптом.

Если падает третий тест (`a genuine guest`), значит `_cachedUser()` возвращает
что-то при пустом хранилище — проверить, что там стоит
`if (id == null || email == null) return null;`.

- [ ] **Step 4: Прогнать всю суиту**

Run:
```bash
flutter test --concurrency=1
```
Expected: PASS. Базовая линия до этого плана — **305 тестов**; должно стать
больше, и ни одного нового падения.

Известная нестабильность: `audio_bloc_test.dart` →
«AudioSegmentDeleted recalculates start positions» падает примерно 1 запуск из
3 **на неизменённом дереве**. Расхождение ровно в этот один тест — не
регрессия. Проверяется повторным запуском только этого файла:
```bash
flutter test test/presentation/audio/bloc/audio_bloc_test.dart --concurrency=1
```

- [ ] **Step 5: Коммит**

```bash
git add test/presentation/session/session_offline_test.dart
git commit -m "test: pin the offline-launch chain from AuthService through NotesRepository"
```

---

## Task 4: Предупреждать о выходе из аккаунта с несинхронизированными правками

Из спеки, раздел 4. Выход офлайн работает, и работа остаётся на устройстве
невидимой, пока человек не вспомнит, каким аккаунтом писал. Предупреждение, не
запрет.

**Files:**
- Modify: `lib/data/repository/notes_repository.dart`
- Modify: `lib/presentation/pages/settings_page.dart`
- Modify: `lib/core/localization/app_strings.dart`
- Test: `test/presentation/pages/settings_page_test.dart`

- [ ] **Step 1: Добавить подсчёт грязных строк в репозиторий**

В `lib/data/repository/notes_repository.dart` добавить метод (рядом с
остальными чтениями, использует тот же `_ownerFilter`):

```dart
  /// How many of this owner's notes have local changes the server has not
  /// acknowledged. Used to warn before a sign-out that would strand them.
  Future<int> pendingSyncCount() async {
    final query = database.selectOnly(database.notes)
      ..addColumns([database.notes.id.count()])
      ..where(
        database.notes.pendingSync.equals(true) &
            _ownerFilter(database.notes.ownerKey),
      );
    final row = await query.getSingle();
    return row.read(database.notes.id.count()) ?? 0;
  }
```

Поле базы в этом классе публичное и называется `database`
(`lib/data/repository/notes_repository.dart:8`), а `_ownerFilter` — приватный
метод того же класса, поэтому обращение к обоим корректно.

- [ ] **Step 2: Добавить строки локализации**

В `lib/core/localization/app_strings.dart` рядом с блоком guest-режима
добавить константы:

```dart
  static const String unsyncedWarningTitle = 'unsynced_warning_title';
  static const String unsyncedWarningBody = 'unsynced_warning_body';
```

Добавить их в список `allKeys` (в конец, перед `];`):

```dart
    unsyncedWarningTitle,
    unsyncedWarningBody,
```

И в каждую из четырёх таблиц переводов:

```dart
      // en
      unsyncedWarningTitle: 'Unsynced entries',
      unsyncedWarningBody:
          'Some entries have not reached the server yet. If you sign out now '
          'they stay on this device, and your colleagues will only see them '
          'after you sign in to this account again.',
```

```dart
      // ru
      unsyncedWarningTitle: 'Несинхронизированные записи',
      unsyncedWarningBody:
          'Часть записей ещё не отправлена на сервер. Если выйти сейчас, они '
          'останутся на этом устройстве, и коллеги увидят их только после '
          'того, как вы снова войдёте в этот аккаунт.',
```

```dart
      // kk
      unsyncedWarningTitle: 'Синхрондалмаған жазбалар',
      unsyncedWarningBody:
          'Кейбір жазбалар серверге әлі жіберілмеген. Қазір шықсаңыз, олар '
          'осы құрылғыда қалады, ал әріптестеріңіз оларды сіз осы аккаунтқа '
          'қайта кіргеннен кейін ғана көреді.',
```

```dart
      // zh
      unsyncedWarningTitle: '未同步的记录',
      unsyncedWarningBody: '部分记录尚未上传到服务器。如果现在退出登录，它们将保留在本设备上，'
          '同事只有在您重新登录此账号后才能看到。',
```

- [ ] **Step 3: Прогнать тест паритета локалей**

Run:
```bash
flutter test test/core/localization/app_strings_test.dart --concurrency=1
```
Expected: PASS. Этот тест проверяет, что новые ключи есть во всех четырёх
языках и не скопированы из английского — если забыть один язык, он покажет
какой именно.

- [ ] **Step 4: Написать падающий тест на предупреждение**

В `test/presentation/pages/settings_page_test.dart` внутрь группы
`'account state is read from SessionCubit, not AuthBloc'` добавить:

```dart
    testWidgets('signing out with unsynced entries warns before logging out', (
      tester,
    ) async {
      when(() => notesRepository.pendingSyncCount()).thenAnswer((_) async => 12);
      givenSession(SessionAuthenticated(user));
      await pumpSettingsPage(tester);

      final signOut = find.text(s(AppStrings.signOut));
      await tester.ensureVisible(signOut);
      await tester.pumpAndSettle();
      await tester.tap(signOut);
      await tester.pumpAndSettle();

      expect(find.text(s(AppStrings.unsyncedWarningTitle)), findsOneWidget);
      verifyNever(() => sessionCubit.logout());
    });
```

`SettingsPage` берёт репозиторий через `context.di.notes.repository`, где `di`
— это расширение `AppScopeContext` (`lib/core/di/app_scope.dart:114`),
делающее `read<Dependencies>()`. Значит в дерево теста нужен
`Provider<Dependencies>`.

Добавить импорты в начало файла:

```dart
import 'package:provider/provider.dart';
import 'package:archset_r2/core/dependencies.dart';
import 'package:archset_r2/data/repository/notes_repository.dart';
import 'package:archset_r2/presentation/notes/notes_dependencies.dart';
```

Мок рядом с остальными моками:

```dart
class _MockNotesRepository extends Mock implements NotesRepository {}

class _FakeDependencies extends Mock implements Dependencies {}
```

Объявления рядом с остальными `late`:

```dart
  late _MockNotesRepository notesRepository;
  late _FakeDependencies dependencies;
```

В `setUp`:

```dart
    notesRepository = _MockNotesRepository();
    when(() => notesRepository.pendingSyncCount()).thenAnswer((_) async => 0);

    dependencies = _FakeDependencies();
    when(() => dependencies.notes)
        .thenReturn(NotesDependencies(repository: notesRepository));
```

В `pumpSettingsPage` обернуть существующий `MultiBlocProvider` в провайдер
зависимостей — заменить `child: const MaterialApp(home: SettingsPage())` на
структуру, где `Provider<Dependencies>` стоит **выше** `MaterialApp`:

```dart
  Future<void> pumpSettingsPage(WidgetTester tester) {
    return tester.pumpWidget(
      Provider<Dependencies>.value(
        value: dependencies,
        child: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<ThemeBloc>.value(value: themeBloc),
            BlocProvider<LocaleBloc>.value(value: localeBloc),
            BlocProvider<TranscriptionBloc>.value(value: transcriptionBloc),
            BlocProvider<SyncBloc>.value(value: syncBloc),
            BlocProvider<SessionCubit>.value(value: sessionCubit),
          ],
          child: const MaterialApp(home: SettingsPage()),
        ),
      ),
    );
  }
```

Мокать `Dependencies` целиком, а не собирать настоящий объект: у него десять
обязательных полей, из которых тесту нужно ровно одно.

- [ ] **Step 5: Убедиться, что тест падает, затем реализовать**

Run:
```bash
flutter test test/presentation/pages/settings_page_test.dart --plain-name "unsynced" --concurrency=1
```
Expected: FAIL — диалог с этим заголовком не появляется.

В `lib/presentation/pages/settings_page.dart`, в начале `_handleSignOut`,
**до** существующего диалога подтверждения, вставить:

```dart
    final pending = await context.di.notes.repository.pendingSyncCount();
    if (!context.mounted) return;

    if (pending > 0) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Theme.of(context).dialogBackgroundColor,
          title: Text(
            AppStrings.tr(locale, AppStrings.unsyncedWarningTitle),
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          content: Text(
            AppStrings.tr(locale, AppStrings.unsyncedWarningBody),
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppStrings.tr(locale, AppStrings.cancel)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                AppStrings.tr(locale, AppStrings.confirm),
                style: GoogleFonts.inter(color: Colors.redAccent),
              ),
            ),
          ],
        ),
      );
      if (proceed != true || !context.mounted) return;
    }
```

Точный путь до репозитория (`context.read<CoreDependencies>().notes.repository`)
проверить и при необходимости поправить:
```bash
rg -n "NotesDependencies|notes" lib/core/dependencies.dart lib/presentation/notes/notes_dependencies.dart
```

- [ ] **Step 6: Прогнать тесты**

Run:
```bash
flutter test test/presentation/pages/settings_page_test.dart --concurrency=1
```
Expected: PASS — новый тест зелёный, и три существующих теста офлайн-выхода
тоже (у них `pendingSyncCount()` замокан нулём, поэтому предупреждение не
всплывает и поведение не меняется).

- [ ] **Step 7: Коммит**

```bash
git add lib/data/repository/notes_repository.dart lib/presentation/pages/settings_page.dart lib/core/localization/app_strings.dart test/presentation/pages/settings_page_test.dart
git commit -m "feat(auth): warn before signing out while entries are still unsynced"
```

---

## Финальная проверка

- [ ] **Прогнать всю суиту и анализатор**

```bash
flutter test --concurrency=1
```
Expected: все тесты зелёные (кроме известной флакости `audio_bloc_test.dart`,
описанной в Task 3 Step 4).

```bash
flutter analyze
```
Expected: **ноль `error`**. Базовая линия по `info`/`warning` — 142 issue;
число может немного вырасти за счёт нового кода в существующем стиле
(`withOpacity`), но новых `error` быть не должно.

- [ ] **Проверить на устройстве**

Единственная проверка, которую тесты не заменяют:

```bash
adb reverse tcp:8000 tcp:8000
```
```bash
flutter run --dart-define-from-file=mapbox.json
```

1. Войти в аккаунт, убедиться что заметки видны.
2. Включить авиарежим.
3. Полностью закрыть и заново открыть приложение.
4. **Ожидается:** заметки на месте, в настройках «Signed in» и почта — не
   «Guest mode». До фикса на этом шаге был пустой дневник.
