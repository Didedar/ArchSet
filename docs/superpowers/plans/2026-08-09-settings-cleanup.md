# Settings Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire up Delete Account (backend + frontend, hard delete, wipes local data), replace the Privacy Policy / Terms of Use stubs with real in-app screens, and remove the non-functional Feature Request row.

**Architecture:** Backend adds one endpoint (`DELETE /api/v1/auth/me`) that leans on an existing SQLAlchemy cascade. Frontend follows the codebase's existing layered auth pattern end to end: `AuthService` (implements `AuthRepository`) → `SessionCubit` (session/routing source of truth) → `SettingsPage`. A new `NotesRepository.wipeAllLocalData()` clears the on-device drift database after a successful delete. Privacy/Terms become a shared `LegalDocumentPage` fed by plain Dart string constants — no networking, no new dependency.

**Tech Stack:** FastAPI + SQLAlchemy (async) + pytest/httpx (backend); Flutter + flutter_bloc + drift + mocktail/bloc_test (frontend).

**Spec:** `docs/superpowers/specs/2026-08-09-settings-cleanup-design.md`

---

## File Structure

**Backend — modified only, no new files:**
- `backend/app/routers/auth.py` — add `DELETE /me`
- `backend/app/services/auth_service.py` — add `AuthService.delete_account`
- `backend/tests/routers/test_auth.py` — add delete-account tests

**Frontend — modified:**
- `lib/domain/repositories/auth_repository.dart` — add `deleteAccount()` to the interface
- `lib/data/services/auth_service.dart` — implement `deleteAccount()`
- `lib/data/repository/notes_repository.dart` — add `wipeAllLocalData()`
- `lib/presentation/session/bloc/session_cubit.dart` — add `SessionCubit.deleteAccount()`
- `lib/core/localization/app_strings.dart` — remove `featureRequest`, add 3 new keys (all 4 locales)
- `lib/presentation/pages/settings_page.dart` — wire Terms/Privacy/Delete Account, remove Feature Request row
- `test/data/repository/notes_repository_test.dart` — cover `wipeAllLocalData()`
- `test/presentation/session/bloc/session_cubit_test.dart` — cover `deleteAccount()`
- `test/presentation/pages/settings_page_test.dart` — cover the new UI wiring

**Frontend — new files:**
- `test/data/services/auth_service_delete_account_test.dart` — HTTP-level coverage for `AuthService.deleteAccount()`, mirroring the existing `auth_service_logout_test.dart`
- `lib/core/legal/legal_text.dart` — the approved draft Privacy Policy / Terms of Use body text as Dart constants
- `lib/presentation/pages/legal_document_page.dart` — the shared scrollable page widget
- `test/presentation/pages/legal_document_page_test.dart` — covers the widget

---

### Task 1: Backend — Delete Account endpoint

**Files:**
- Modify: `backend/tests/routers/test_auth.py`
- Modify: `backend/app/services/auth_service.py`
- Modify: `backend/app/routers/auth.py`

- [ ] **Step 1: Write the failing tests**

Edit `backend/tests/routers/test_auth.py`. Replace the import block at the top:

```python
"""Tests for /api/v1/auth: register, login, refresh, me."""

import pytest
from httpx import AsyncClient

from app.models.user import User
from app.utils.security import create_access_token, create_refresh_token
```

with:

```python
"""Tests for /api/v1/auth: register, login, refresh, me, delete."""

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.folder import Folder
from app.models.note import Note
from app.models.user import User
from app.utils.security import create_access_token, create_refresh_token
```

Then append these tests at the end of the file (after `test_me_rejects_an_invalid_token`):

```python
@pytest.mark.asyncio
async def test_delete_account_removes_the_user(
    client: AsyncClient, test_user: User, auth_headers: dict
):
    response = await client.delete("/api/v1/auth/me", headers=auth_headers)

    assert response.status_code == 204


@pytest.mark.asyncio
async def test_delete_account_revokes_the_access_token(
    client: AsyncClient, test_user: User, auth_headers: dict
):
    await client.delete("/api/v1/auth/me", headers=auth_headers)

    response = await client.get("/api/v1/auth/me", headers=auth_headers)

    assert response.status_code == 401


@pytest.mark.asyncio
async def test_delete_account_requires_a_token(client: AsyncClient):
    response = await client.delete("/api/v1/auth/me")

    assert response.status_code == 401


@pytest.mark.asyncio
async def test_delete_account_does_not_affect_other_users(
    client: AsyncClient,
    test_user: User,
    auth_headers: dict,
    other_user: User,
    other_auth_headers: dict,
):
    response = await client.delete("/api/v1/auth/me", headers=auth_headers)
    assert response.status_code == 204

    response = await client.get("/api/v1/auth/me", headers=other_auth_headers)
    assert response.status_code == 200
    assert response.json()["email"] == other_user.email


@pytest.mark.asyncio
async def test_delete_account_cascades_to_folders_and_notes(
    client: AsyncClient,
    test_user: User,
    auth_headers: dict,
    db_session: AsyncSession,
):
    folder = Folder(user_id=test_user.id, name="Trench A")
    db_session.add(folder)
    await db_session.commit()
    await db_session.refresh(folder)

    note = Note(
        user_id=test_user.id,
        folder_id=folder.id,
        title="Day 1",
        content="Context 42",
    )
    db_session.add(note)
    await db_session.commit()

    response = await client.delete("/api/v1/auth/me", headers=auth_headers)
    assert response.status_code == 204

    remaining_folders = await db_session.execute(
        select(Folder).where(Folder.user_id == test_user.id)
    )
    remaining_notes = await db_session.execute(
        select(Note).where(Note.user_id == test_user.id)
    )
    assert remaining_folders.scalar_one_or_none() is None
    assert remaining_notes.scalar_one_or_none() is None
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd backend && python -m pytest tests/routers/test_auth.py -k delete_account -v`
Expected: FAIL — `405 Method Not Allowed` for every new test (no `DELETE /me` route exists yet).

- [ ] **Step 3: Add `AuthService.delete_account`**

Edit `backend/app/services/auth_service.py`. Add this method as the last method in the `AuthService` class, right after `refresh_tokens` (i.e. append it before the class's closing, using the same indentation as the other methods):

```python

    async def delete_account(self, user: User) -> None:
        """Permanently delete a user account and all associated data.

        Relies on the cascade="all, delete-orphan" relationships declared on
        User (folders/notes/artifacts/artifact_comments) to remove every row
        that belongs to this user.
        """
        await self.db.delete(user)
        await self.db.commit()
```

- [ ] **Step 4: Add the `DELETE /me` route**

Edit `backend/app/routers/auth.py`. Append this route at the end of the file, after `get_current_user_info`:

```python


@router.delete("/me", status_code=204)
async def delete_account(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Permanently delete the authenticated user's account and all their data.

    This cannot be undone. Requires a valid JWT access token in the
    Authorization header.
    """
    service = AuthService(db)
    await service.delete_account(current_user)
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd backend && python -m pytest tests/routers/test_auth.py -v`
Expected: PASS — all tests in the file, including the 5 new ones.

- [ ] **Step 6: Run the full backend suite**

Run: `cd backend && python -m pytest -v`
Expected: PASS — no regressions elsewhere (this only adds a route + service method, touches nothing else).

- [ ] **Step 7: Commit**

```bash
git add backend/app/routers/auth.py backend/app/services/auth_service.py backend/tests/routers/test_auth.py
git commit -m "feat(backend): add DELETE /api/v1/auth/me to permanently delete an account"
```

---

### Task 2: Frontend — `AuthRepository.deleteAccount()` + `AuthService.deleteAccount()`

**Files:**
- Modify: `lib/domain/repositories/auth_repository.dart`
- Modify: `lib/data/services/auth_service.dart`
- Create: `test/data/services/auth_service_delete_account_test.dart`

- [ ] **Step 1: Add `deleteAccount()` to the `AuthRepository` interface**

Edit `lib/domain/repositories/auth_repository.dart`. Replace the whole file:

```dart
import '../../data/services/auth_service.dart' show AuthUser;

abstract interface class AuthRepository {
  AuthUser? get currentUser;
  Future<AuthUser> login(String email, String password);
  Future<AuthUser> register(String email, String password);
  Future<void> logout();
  Future<void> deleteAccount();
  Future<AuthUser?> loadStoredUser();
}
```

- [ ] **Step 2: Write the failing test**

Create `test/data/services/auth_service_delete_account_test.dart`:

```dart
import 'package:archset_r2/data/services/auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/fake_secure_storage.dart';

/// Mirrors auth_service_logout_test.dart: deleteAccount() must clear the
/// namespaced session exactly like logout() does (the tokens are dead on
/// the server either way), but -- unlike logout() -- it must NOT clear
/// anything if the server call fails, since the account (and its session)
/// still exists in that case.
const _baseUrl = 'http://127.0.0.1:8000';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> storageValues;

  setUp(() {
    storageValues = installFakeSecureStorage();
  });

  test(
    'deleteAccount sends a DELETE with the bearer token and clears the '
    'namespaced session on success',
    () async {
      final slug = AuthStorageKeys.originSlug(_baseUrl);
      http.Request? sentRequest;
      final client = MockClient((request) async {
        sentRequest = request;
        return http.Response('', 204);
      });
      final service = AuthService(
        storage: const FlutterSecureStorage(),
        baseUrl: _baseUrl,
        client: client,
      );
      addTearDown(service.dispose);

      storageValues[AuthStorageKeys.accessToken(slug)] = 'access-token';
      storageValues[AuthStorageKeys.refreshToken(slug)] = 'refresh-token';
      storageValues[AuthStorageKeys.userId(slug)] = 'user-1';
      storageValues[AuthStorageKeys.userEmail(slug)] = 'a@example.com';
      storageValues[AuthStorageKeys.userCreatedAt(slug)] =
          '2026-01-01T00:00:00.000Z';
      storageValues[AuthStorageKeys.currentOwnerId] = 'user-1';

      await service.deleteAccount();

      expect(sentRequest?.method, 'DELETE');
      expect(sentRequest?.url.path, endsWith('/auth/me'));
      expect(
        sentRequest?.headers['Authorization'],
        'Bearer access-token',
      );

      expect(
        storageValues.containsKey(AuthStorageKeys.accessToken(slug)),
        isFalse,
      );
      expect(
        storageValues.containsKey(AuthStorageKeys.refreshToken(slug)),
        isFalse,
      );
      expect(storageValues.containsKey(AuthStorageKeys.userId(slug)), isFalse);
      expect(
        storageValues.containsKey(AuthStorageKeys.userEmail(slug)),
        isFalse,
      );
      expect(
        storageValues.containsKey(AuthStorageKeys.userCreatedAt(slug)),
        isFalse,
      );
      expect(
        storageValues.containsKey(AuthStorageKeys.currentOwnerId),
        isFalse,
      );
    },
  );

  test(
    'deleteAccount throws and leaves the session untouched when the server '
    'rejects the request',
    () async {
      final slug = AuthStorageKeys.originSlug(_baseUrl);
      final client = MockClient(
        (request) async => http.Response(
          '{"detail": "Could not validate credentials"}',
          401,
        ),
      );
      final service = AuthService(
        storage: const FlutterSecureStorage(),
        baseUrl: _baseUrl,
        client: client,
      );
      addTearDown(service.dispose);

      storageValues[AuthStorageKeys.accessToken(slug)] = 'access-token';

      await expectLater(service.deleteAccount(), throwsA(isA<Exception>()));

      expect(
        storageValues.containsKey(AuthStorageKeys.accessToken(slug)),
        isTrue,
      );
    },
  );
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/data/services/auth_service_delete_account_test.dart`
Expected: FAIL — `deleteAccount` is not a method on `AuthService` (compile error).

- [ ] **Step 4: Implement `AuthService.deleteAccount()`**

Edit `lib/data/services/auth_service.dart`. Add the new method right after `logout()` (which ends at line 362 with the closing `}`), so it reads:

```dart
  /// Local sign-out. Clears ONLY the namespaced session + current owner id.
  /// The on-device diary (notes/folders/artifacts) is intentionally left
  /// untouched — logging out must not destroy the user's local data.
  @override
  Future<void> logout() async {
    _currentUser = null;
    await _clearNamespacedSession();
  }

  /// Permanently deletes the signed-in account on the server. Clears the
  /// namespaced session on success, exactly like [logout] -- the tokens are
  /// dead either way once the account is gone. Throws and leaves the
  /// session untouched on failure: the account (and its session) still
  /// exists in that case, so nothing local should change.
  ///
  /// Deliberately does not touch the on-device diary (notes/folders) --
  /// that's the caller's job once this succeeds, same separation of
  /// concerns [logout] already keeps.
  @override
  Future<void> deleteAccount() async {
    final token = await getAccessToken();
    final response = await _client
        .delete(
          Uri.parse('$_baseUrl/auth/me'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(_requestTimeout);

    if (response.statusCode != 204) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to delete account');
    }

    _currentUser = null;
    await _clearNamespacedSession();
  }
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/data/services/auth_service_delete_account_test.dart`
Expected: PASS — both tests.

- [ ] **Step 6: Run the full frontend test suite**

Run: `flutter test --concurrency=1`
Expected: PASS. (Per project convention, the Flutter suite is flaky under the default concurrency — always run with `--concurrency=1`.)

Note: `test/presentation/session/bloc/session_cubit_test.dart` and `test/presentation/pages/settings_page_test.dart` use `Mock`/`MockCubit` implementations of `AuthRepository`/`SessionCubit`, which auto-implement any new interface method with a throwing stub -- they compile and keep passing unchanged at this step since nothing yet calls `deleteAccount()` on those mocks.

- [ ] **Step 7: Commit**

```bash
git add lib/domain/repositories/auth_repository.dart lib/data/services/auth_service.dart test/data/services/auth_service_delete_account_test.dart
git commit -m "feat(auth): add AuthService.deleteAccount()"
```

---

### Task 3: Frontend — `NotesRepository.wipeAllLocalData()`

**Files:**
- Modify: `lib/data/repository/notes_repository.dart`
- Modify: `test/data/repository/notes_repository_test.dart`

- [ ] **Step 1: Write the failing tests**

Edit `test/data/repository/notes_repository_test.dart`. Add this new group right before the final closing `}` of `main()` (after whatever the last existing group in the file is):

```dart

  group('wipeAllLocalData', () {
    test('deletes every row from every table', () async {
      await repository.createFolder(folder('f1'));
      await repository.insertNote(note('n1', folderId: 'f1'));

      await repository.wipeAllLocalData();

      expect(await database.select(database.folders).get(), isEmpty);
      expect(await database.select(database.notes).get(), isEmpty);
    });

    test('clears rows regardless of which owner they belong to', () async {
      ownerHolder.value = 'user-1';
      await repository.createFolder(folder('f1'));
      ownerHolder.value = null;
      await repository.insertNote(note('n2'));

      await repository.wipeAllLocalData();

      expect(await database.select(database.folders).get(), isEmpty);
      expect(await database.select(database.notes).get(), isEmpty);
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/data/repository/notes_repository_test.dart --concurrency=1`
Expected: FAIL — `wipeAllLocalData` is not a method on `NotesRepository` (compile error).

- [ ] **Step 3: Implement `wipeAllLocalData()`**

Edit `lib/data/repository/notes_repository.dart`. The class currently ends with `pendingSyncCount()` immediately followed by the closing `}` of the class (lines 495-507). Replace:

```dart
  Future<int> pendingSyncCount() async {
    final count = database.notes.id.count();
    final query = database.selectOnly(database.notes)
      ..addColumns([count])
      ..where(
        database.notes.pendingSync.equals(true) &
            _ownerFilter(database.notes.ownerKey),
      );

    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }
}
```

with:

```dart
  Future<int> pendingSyncCount() async {
    final count = database.notes.id.count();
    final query = database.selectOnly(database.notes)
      ..addColumns([count])
      ..where(
        database.notes.pendingSync.equals(true) &
            _ownerFilter(database.notes.ownerKey),
      );

    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Deletes every row from every table, regardless of owner.
  ///
  /// Used only when the signed-in account is permanently deleted: unlike
  /// sign-out, which deliberately preserves local data so a returning user
  /// doesn't lose anything, account deletion means there is no server copy
  /// left to sync back to, so nothing is left behind on the device either.
  Future<void> wipeAllLocalData() async {
    await database.transaction(() async {
      await database.delete(database.notes).go();
      await database.delete(database.folders).go();
      await database.delete(database.imageMetadata).go();
      await database.delete(database.artifactComments).go();
    });
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/data/repository/notes_repository_test.dart --concurrency=1`
Expected: PASS — including the 2 new tests.

- [ ] **Step 5: Run the full frontend test suite**

Run: `flutter test --concurrency=1`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/data/repository/notes_repository.dart test/data/repository/notes_repository_test.dart
git commit -m "feat(notes): add NotesRepository.wipeAllLocalData()"
```

---

### Task 4: Frontend — `SessionCubit.deleteAccount()`

**Files:**
- Modify: `lib/presentation/session/bloc/session_cubit.dart`
- Modify: `test/presentation/session/bloc/session_cubit_test.dart`

- [ ] **Step 1: Write the failing tests**

Edit `test/presentation/session/bloc/session_cubit_test.dart`. Add this new group right after the `group('logout', ...)` block (i.e. between `logout` and `sessionLost`):

```dart

  group('deleteAccount', () {
    blocTest<SessionCubit, AppSession>(
      'emits SessionUnauthenticated and calls repository.deleteAccount()',
      setUp: () =>
          when(() => repository.deleteAccount()).thenAnswer((_) async {}),
      build: () => SessionCubit(repository: repository),
      act: (cubit) => cubit.deleteAccount(),
      expect: () => [const SessionUnauthenticated()],
      verify: (_) {
        verify(() => repository.deleteAccount()).called(1);
      },
    );

    blocTest<SessionCubit, AppSession>(
      'emits nothing and rethrows when repository.deleteAccount() fails',
      setUp: () => when(
        () => repository.deleteAccount(),
      ).thenThrow(Exception('network error')),
      build: () => SessionCubit(repository: repository),
      act: (cubit) => cubit.deleteAccount(),
      errors: () => [isA<Exception>()],
      expect: () => <AppSession>[],
    );
  });
```

Also add this test inside the existing `group('ownerHolder', ...)` block, right after the `'reverts to null on logout after being set by loginSuccess'` test:

```dart

    blocTest<SessionCubit, AppSession>(
      'reverts to null on deleteAccount after being set by loginSuccess',
      setUp: () =>
          when(() => repository.deleteAccount()).thenAnswer((_) async {}),
      build: () => SessionCubit(repository: repository, ownerHolder: holder),
      act: (cubit) async {
        cubit.loginSuccess(user);
        await cubit.deleteAccount();
      },
      verify: (_) => expect(holder.value, isNull),
    );
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/presentation/session/bloc/session_cubit_test.dart --concurrency=1`
Expected: FAIL — `deleteAccount` is not a method on `SessionCubit` (compile error).

- [ ] **Step 3: Implement `SessionCubit.deleteAccount()`**

Edit `lib/presentation/session/bloc/session_cubit.dart`. Replace:

```dart
  Future<void> logout() async {
    await _repository.logout();
    _emit(const SessionUnauthenticated());
  }

  void sessionLost() => _emit(const SessionUnauthenticated());
```

with:

```dart
  Future<void> logout() async {
    await _repository.logout();
    _emit(const SessionUnauthenticated());
  }

  /// Permanently deletes the signed-in account and transitions to
  /// [SessionUnauthenticated] -- the same terminal state [logout] reaches,
  /// so routing needs no separate handling for it.
  ///
  /// Deliberately does not touch local diary data; unlike [logout], the
  /// caller (SettingsPage) wipes it separately, and only after this
  /// completes successfully. Propagates any failure from the repository
  /// instead of swallowing it, so the caller knows the account was NOT
  /// deleted and must not wipe anything.
  Future<void> deleteAccount() async {
    await _repository.deleteAccount();
    _emit(const SessionUnauthenticated());
  }

  void sessionLost() => _emit(const SessionUnauthenticated());
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/presentation/session/bloc/session_cubit_test.dart --concurrency=1`
Expected: PASS — including the 3 new tests.

- [ ] **Step 5: Run the full frontend test suite**

Run: `flutter test --concurrency=1`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/session/bloc/session_cubit.dart test/presentation/session/bloc/session_cubit_test.dart
git commit -m "feat(session): add SessionCubit.deleteAccount()"
```

---

### Task 5: Frontend — `AppStrings`: remove Feature Request, add Delete Account confirmation strings

**Files:**
- Modify: `lib/core/localization/app_strings.dart`

- [ ] **Step 1: Remove the `featureRequest` key declaration**

Edit `lib/core/localization/app_strings.dart`. Replace:

```dart
  static const String termsOfUse = 'terms_of_use';
  static const String privacyPolicy = 'privacy_policy';
  static const String featureRequest = 'feature_request';
  static const String darkMode = 'dark_mode';
```

with:

```dart
  static const String termsOfUse = 'terms_of_use';
  static const String privacyPolicy = 'privacy_policy';
  static const String darkMode = 'dark_mode';
```

- [ ] **Step 2: Add the 3 new key declarations**

In the same file, replace:

```dart
  static const String deleteAccount = 'delete_account';
  static const String hello = 'hello';
```

with:

```dart
  static const String deleteAccount = 'delete_account';
  static const String deleteAccountConfirmTitle = 'delete_account_confirm_title';
  static const String deleteAccountConfirmMessage =
      'delete_account_confirm_message';
  static const String deleteAccountFailed = 'delete_account_failed';
  static const String hello = 'hello';
```

- [ ] **Step 3: Update `allKeys`**

Replace:

```dart
    termsOfUse,
    privacyPolicy,
    featureRequest,
    darkMode,
```

with:

```dart
    termsOfUse,
    privacyPolicy,
    darkMode,
```

Replace:

```dart
    deleteAccount,
    hello,
```

with:

```dart
    deleteAccount,
    deleteAccountConfirmTitle,
    deleteAccountConfirmMessage,
    deleteAccountFailed,
    hello,
```

- [ ] **Step 4: Remove `featureRequest` from every locale table**

In the `'en'` map, replace:

```dart
      termsOfUse: 'Terms of Use',
      privacyPolicy: 'Privacy Policy',
      featureRequest: 'Feature request',
      darkMode: 'Dark mode',
```

with:

```dart
      termsOfUse: 'Terms of Use',
      privacyPolicy: 'Privacy Policy',
      darkMode: 'Dark mode',
```

In the `'ru'` map, replace:

```dart
      termsOfUse: 'Условия использования',
      privacyPolicy: 'Политика конфиденциальности',
      featureRequest: 'Запрос функций',
      darkMode: 'Тёмная тема',
```

with:

```dart
      termsOfUse: 'Условия использования',
      privacyPolicy: 'Политика конфиденциальности',
      darkMode: 'Тёмная тема',
```

In the `'kk'` map, replace:

```dart
      termsOfUse: 'Пайдалану шарттары',
      privacyPolicy: 'Құпиялылық саясаты',
      featureRequest: 'Функция сұрау',
      darkMode: 'Қараңғы режим',
```

with:

```dart
      termsOfUse: 'Пайдалану шарттары',
      privacyPolicy: 'Құпиялылық саясаты',
      darkMode: 'Қараңғы режим',
```

In the `'zh'` map, replace:

```dart
      termsOfUse: '使用条款',
      privacyPolicy: '隐私政策',
      featureRequest: '功能请求',
      darkMode: '深色模式',
```

with:

```dart
      termsOfUse: '使用条款',
      privacyPolicy: '隐私政策',
      darkMode: '深色模式',
```

- [ ] **Step 5: Add the 3 new keys' translations to every locale table**

In the `'en'` map, replace:

```dart
      deleteAccount: 'Delete Account',
      hello: 'Hello',
```

with:

```dart
      deleteAccount: 'Delete Account',
      deleteAccountConfirmTitle: 'Delete Account',
      deleteAccountConfirmMessage:
          'This will permanently delete your account and all your diary '
          'data. This cannot be undone.',
      deleteAccountFailed:
          'Failed to delete account. Please check your connection and try '
          'again.',
      hello: 'Hello',
```

In the `'ru'` map, replace:

```dart
      deleteAccount: 'Удалить аккаунт',
      hello: 'Привет',
```

with:

```dart
      deleteAccount: 'Удалить аккаунт',
      deleteAccountConfirmTitle: 'Удалить аккаунт',
      deleteAccountConfirmMessage:
          'Аккаунт и весь дневник будут удалены навсегда. Это действие '
          'нельзя отменить.',
      deleteAccountFailed:
          'Не удалось удалить аккаунт. Проверьте соединение и попробуйте '
          'снова.',
      hello: 'Привет',
```

In the `'kk'` map, replace:

```dart
      deleteAccount: 'Аккаунтты өшіру',
      hello: 'Сәлем',
```

with:

```dart
      deleteAccount: 'Аккаунтты өшіру',
      deleteAccountConfirmTitle: 'Аккаунтты өшіру',
      deleteAccountConfirmMessage:
          'Аккаунт және барлық күнделік деректері толығымен өшіріледі. Бұл '
          'әрекетті қайтару мүмкін емес.',
      deleteAccountFailed:
          'Аккаунтты өшіру сәтсіз аяқталды. Байланысты тексеріп, қайталап '
          'көріңіз.',
      hello: 'Сәлем',
```

In the `'zh'` map, replace:

```dart
      deleteAccount: '删除账户',
      hello: '你好',
```

with:

```dart
      deleteAccount: '删除账户',
      deleteAccountConfirmTitle: '删除账户',
      deleteAccountConfirmMessage: '这将永久删除您的账户和全部日记数据，此操作无法撤销。',
      deleteAccountFailed: '删除账户失败，请检查网络连接后重试。',
      hello: '你好',
```

- [ ] **Step 6: Run the localization tests**

Run: `flutter test test/core/localization/app_strings_test.dart --concurrency=1`
Expected: PASS — locale parity holds for the 3 new keys, and `featureRequest` is gone so nothing references it.

- [ ] **Step 7: Confirm nothing else references the removed key**

Run: `grep -rn "featureRequest" lib/ test/`
Expected: no output. (`settings_page.dart` still references it until Task 7 — if this grep is run before Task 7 lands, `settings_page.dart` will show up; that's expected and gets resolved in Task 7. Re-run this check again at the end of Task 7.)

- [ ] **Step 8: Commit**

```bash
git add lib/core/localization/app_strings.dart
git commit -m "feat(i18n): remove feature_request, add delete-account confirmation strings"
```

Note: `flutter analyze` will report an undefined-identifier error in `settings_page.dart` after this commit, until Task 7 removes that row. That's expected mid-plan; Task 7 fixes it in the same session.

---

### Task 6: Frontend — Legal document content + shared page widget

**Files:**
- Create: `lib/core/legal/legal_text.dart`
- Create: `lib/presentation/pages/legal_document_page.dart`
- Create: `test/presentation/pages/legal_document_page_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/presentation/pages/legal_document_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/presentation/pages/legal_document_page.dart';

void main() {
  testWidgets('renders the given title in the app bar and the body text', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LegalDocumentPage(
          title: 'Privacy Policy',
          body: 'This is the policy body.',
        ),
      ),
    );

    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('This is the policy body.'), findsOneWidget);
  });

  testWidgets('is pushable and popped by the back button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const LegalDocumentPage(
                  title: 'Terms of Use',
                  body: 'Terms body.',
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Terms of Use'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Terms of Use'), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/presentation/pages/legal_document_page_test.dart --concurrency=1`
Expected: FAIL — `package:archset_r2/presentation/pages/legal_document_page.dart` does not exist.

- [ ] **Step 3: Create the legal text content**

Create `lib/core/legal/legal_text.dart`:

```dart
/// English-only draft Privacy Policy / Terms of Use body text.
///
/// Source of truth and review status:
/// docs/superpowers/specs/2026-08-09-settings-cleanup-design.md
library;

class LegalText {
  const LegalText._();

  static const String privacyPolicy = '''
Last updated: August 2026

ArchSet ("the app", "we", "us") is an offline-first diary application for archaeologists. This policy explains what information the app collects, how it's used, and how you can delete it.

Information we collect

Account information: if you create an account, we store your email address and a securely hashed password. You can also use the app fully offline as a guest, without an account — in that case we don't collect any account information at all.

Diary content: notes, folders, photos, and audio recordings you create in the app, along with any location coordinates you attach to an archaeological find.

Sync data: if you're signed in, your diary content is synced to our server so it's available across sessions and (in the future) devices. If you never sign in, your diary content stays on your device only.

How we use AI features

The app offers two transcription/rewriting modes, and the choice is always yours:

Offline (Whisper): audio is transcribed entirely on your device. Nothing is sent anywhere.

Online (Gemini): if you choose this mode, the relevant audio or text is sent to Google's Gemini API for transcription or archaeological-text rewriting, subject to Google's own privacy terms. We don't use this data for anything beyond returning the result to you.

Where your data is stored

Locally on your device, in an encrypted local database.

Authentication tokens are stored using your device's secure storage (Keychain on iOS, Keystore on Android).

If you're signed in, your synced diary content is stored on our Postgres database, hosted on Railway.

Your rights

You can delete your account and all associated data at any time from Settings → Delete Account. This permanently and immediately removes your account, your synced diary content, and everything associated with it from our server — this action cannot be undone. If you'd rather make the request by email, or have any other question about your data, contact us at sabyrhandarhan@gmail.com.

Children's privacy

ArchSet is not directed at children under 13, and we don't knowingly collect information from children under 13.

Changes to this policy

If this policy changes in a meaningful way, we'll update the "last updated" date above. Continued use of the app after a change means you accept the updated policy.

Contact

sabyrhandarhan@gmail.com
''';

  static const String termsOfUse = '''
Last updated: August 2026

By using ArchSet, you agree to these terms.

The service

ArchSet is an offline-first diary application for archaeologists. You can use it fully offline without an account (guest mode), or create an account to sync your diary content to our server.

Your content

You own everything you create in the app — your notes, photos, audio recordings, and any other diary content. By syncing content to our server (when signed in), you grant us the limited right to store and process that content solely for the purpose of providing the app's features to you (sync, search, AI transcription/rewriting when you choose to use it). We don't claim ownership of your content and we don't use it for anything else.

Acceptable use

Don't use ArchSet to store or process unlawful content, or to attempt to disrupt or abuse the service.

AI features

Transcription and text-rewriting features are provided for convenience. They can make mistakes — always review AI-generated text before relying on it for your records.

Account and termination

You can delete your account at any time from Settings → Delete Account, which permanently removes your account and its synced data immediately. We may suspend or terminate access for accounts that violate these terms.

No warranty

ArchSet is provided "as is," without warranty of any kind. We do reasonable best efforts to keep the service available and your data safe, but we don't guarantee uninterrupted availability or that the service will be error-free.

Changes to these terms

If these terms change in a meaningful way, we'll update the "last updated" date above. Continued use of the app after a change means you accept the updated terms.

Contact

sabyrhandarhan@gmail.com
''';
}
```

- [ ] **Step 4: Create the page widget**

Create `lib/presentation/pages/legal_document_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A simple scrollable page for static legal text (Privacy Policy, Terms of
/// Use). Shared by both so the two don't diverge in presentation.
class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        title: Text(
          title,
          style: GoogleFonts.inter(
            color: colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            body,
            style: GoogleFonts.inter(
              color: colorScheme.onSurface.withOpacity(0.85),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/presentation/pages/legal_document_page_test.dart --concurrency=1`
Expected: PASS — both tests.

- [ ] **Step 6: Commit**

```bash
git add lib/core/legal/legal_text.dart lib/presentation/pages/legal_document_page.dart test/presentation/pages/legal_document_page_test.dart
git commit -m "feat(legal): add LegalDocumentPage and draft Privacy Policy / Terms of Use text"
```

---

### Task 7: Frontend — Wire up `SettingsPage`

**Files:**
- Modify: `lib/presentation/pages/settings_page.dart`
- Modify: `test/presentation/pages/settings_page_test.dart`

- [ ] **Step 1: Write the failing tests**

Edit `test/presentation/pages/settings_page_test.dart`.

First, add two imports at the top, alongside the existing ones:

```dart
import 'package:archset_r2/presentation/pages/legal_document_page.dart';
import 'package:archset_r2/core/legal/legal_text.dart';
```

Second, in `setUp`, add a stub for the new repository method right after the existing `pendingSyncCount` stub:

```dart
    notesRepository = _MockNotesRepository();
    when(() => notesRepository.pendingSyncCount()).thenAnswer((_) async => 0);
    when(
      () => notesRepository.wipeAllLocalData(),
    ).thenAnswer((_) async {});
```

Third, in the same `setUp`, add a stub for the new `SessionCubit.deleteAccount()` method right after the existing `sessionCubit.logout()` stub:

```dart
    sessionCubit = _MockSessionCubit();
    whenListen(
      sessionCubit,
      const Stream<AppSession>.empty(),
      initialState: SessionAuthenticated(user),
    );
    when(() => sessionCubit.logout()).thenAnswer((_) async {});
    when(() => sessionCubit.deleteAccount()).thenAnswer((_) async {});
```

Fourth, add these new tests inside the existing `group('account state is read from SessionCubit, not AuthBloc', ...)` block, right after the `'a signed-in user is shown as having an account...'` test (i.e. before `'a lost/expired session is treated as no account'`):

```dart

    testWidgets('tapping Terms of Use opens the terms page', (tester) async {
      givenSession(SessionAuthenticated(user));
      await pumpSettingsPage(tester);

      final row = find.text(s(AppStrings.termsOfUse));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.byType(LegalDocumentPage), findsOneWidget);
      expect(find.text(LegalText.termsOfUse), findsOneWidget);
    });

    testWidgets('tapping Privacy Policy opens the privacy page', (
      tester,
    ) async {
      givenSession(SessionAuthenticated(user));
      await pumpSettingsPage(tester);

      final row = find.text(s(AppStrings.privacyPolicy));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.byType(LegalDocumentPage), findsOneWidget);
      expect(find.text(LegalText.privacyPolicy), findsOneWidget);
    });

    testWidgets('the feature request row no longer exists', (tester) async {
      givenSession(SessionAuthenticated(user));
      await pumpSettingsPage(tester);

      expect(find.byIcon(Icons.card_membership_outlined), findsNothing);
    });

    testWidgets(
      'confirming Delete Account calls SessionCubit.deleteAccount() then '
      'wipes local data',
      (tester) async {
        givenSession(SessionAuthenticated(user));
        await pumpSettingsPage(tester);

        final row = find.text(s(AppStrings.deleteAccount));
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pumpAndSettle();

        expect(
          find.text(s(AppStrings.deleteAccountConfirmMessage)),
          findsOneWidget,
        );

        // Delete is the dialog's last TextButton (Cancel is first).
        await tester.tap(
          find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(TextButton),
              )
              .last,
        );
        await tester.pumpAndSettle();

        verify(() => sessionCubit.deleteAccount()).called(1);
        verify(() => notesRepository.wipeAllLocalData()).called(1);
      },
    );

    testWidgets('declining the Delete Account confirmation deletes nothing', (
      tester,
    ) async {
      givenSession(SessionAuthenticated(user));
      await pumpSettingsPage(tester);

      final row = find.text(s(AppStrings.deleteAccount));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();

      // Cancel is the dialog's first TextButton.
      await tester.tap(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextButton),
            )
            .first,
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(() => sessionCubit.deleteAccount());
      verifyNever(() => notesRepository.wipeAllLocalData());
    });

    testWidgets(
      'a failed Delete Account shows an error and does not wipe local data',
      (tester) async {
        when(
          () => sessionCubit.deleteAccount(),
        ).thenThrow(Exception('network error'));
        givenSession(SessionAuthenticated(user));
        await pumpSettingsPage(tester);

        final row = find.text(s(AppStrings.deleteAccount));
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pumpAndSettle();

        await tester.tap(
          find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(TextButton),
              )
              .last,
        );
        await tester.pumpAndSettle();

        expect(find.text(s(AppStrings.deleteAccountFailed)), findsOneWidget);
        verifyNever(() => notesRepository.wipeAllLocalData());
      },
    );
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/presentation/pages/settings_page_test.dart --concurrency=1`
Expected: FAIL — compile errors (`wipeAllLocalData`/`deleteAccount` stubs reference real methods that exist by now from Tasks 3/4, so this should instead fail on assertions: Terms/Privacy taps do nothing, the feature-request icon is still present, and the delete flow does nothing since `onTap` is still a no-op stub).

- [ ] **Step 3: Add the imports**

Edit `lib/presentation/pages/settings_page.dart`. Replace the import block:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/di/app_scope.dart';
import '../auth/pages/sign_in_email_page.dart';
import '../locale/bloc/locale_bloc.dart';
import '../session/bloc/session_cubit.dart';
import '../sync/bloc/sync_bloc.dart';
import '../theme/bloc/theme_bloc.dart';
import '../transcription/bloc/transcription_bloc.dart';
import '../../core/localization/app_strings.dart';
```

with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/di/app_scope.dart';
import '../../core/legal/legal_text.dart';
import '../auth/pages/sign_in_email_page.dart';
import '../locale/bloc/locale_bloc.dart';
import '../session/bloc/session_cubit.dart';
import '../sync/bloc/sync_bloc.dart';
import '../theme/bloc/theme_bloc.dart';
import '../transcription/bloc/transcription_bloc.dart';
import '../../core/localization/app_strings.dart';
import 'legal_document_page.dart';
```

- [ ] **Step 4: Wire Terms of Use and Privacy Policy, remove Feature Request**

In the same file, replace:

```dart
                child: Column(
                  children: [
                    _buildMenuItem(
                      context,
                      icon: Icons.description_outlined,
                      text: AppStrings.tr(currentLocale, AppStrings.termsOfUse),
                      onTap: () {}, // TODO: Implement URL launch
                      textColor: textColor,
                    ),
                    _buildDivider(context),
                    _buildMenuItem(
                      context,
                      icon: Icons.privacy_tip_outlined,
                      text: AppStrings.tr(
                        currentLocale,
                        AppStrings.privacyPolicy,
                      ),
                      onTap: () {}, // TODO: Implement URL launch
                      textColor: textColor,
                    ),
                    _buildDivider(context),
                    _buildMenuItem(
                      context,
                      icon: Icons.card_membership_outlined,
                      text: AppStrings.tr(
                        currentLocale,
                        AppStrings.featureRequest,
                      ),
                      onTap: () {}, // TODO: Implement URL launch
                      textColor: textColor,
                    ),
                  ],
                ),
```

with:

```dart
                child: Column(
                  children: [
                    _buildMenuItem(
                      context,
                      icon: Icons.description_outlined,
                      text: AppStrings.tr(currentLocale, AppStrings.termsOfUse),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => LegalDocumentPage(
                            title: AppStrings.tr(
                              currentLocale,
                              AppStrings.termsOfUse,
                            ),
                            body: LegalText.termsOfUse,
                          ),
                        ),
                      ),
                      textColor: textColor,
                    ),
                    _buildDivider(context),
                    _buildMenuItem(
                      context,
                      icon: Icons.privacy_tip_outlined,
                      text: AppStrings.tr(
                        currentLocale,
                        AppStrings.privacyPolicy,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => LegalDocumentPage(
                            title: AppStrings.tr(
                              currentLocale,
                              AppStrings.privacyPolicy,
                            ),
                            body: LegalText.privacyPolicy,
                          ),
                        ),
                      ),
                      textColor: textColor,
                    ),
                  ],
                ),
```

- [ ] **Step 5: Wire the Delete Account row**

In the same file, replace:

```dart
                // Delete Account
                Container(
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _buildMenuItem(
                    context,
                    icon: Icons.delete_outline,
                    text: AppStrings.tr(
                      currentLocale,
                      AppStrings.deleteAccount,
                    ),
                    color: const Color(0xFFE99C9C), // Keep red tint
                    onTap: () {}, // TODO: Implement delete account
                    textColor: const Color(0xFFE99C9C),
                  ),
                ),
```

with:

```dart
                // Delete Account
                Container(
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _buildMenuItem(
                    context,
                    icon: Icons.delete_outline,
                    text: AppStrings.tr(
                      currentLocale,
                      AppStrings.deleteAccount,
                    ),
                    color: const Color(0xFFE99C9C), // Keep red tint
                    onTap: () => _handleDeleteAccount(context, currentLocale),
                    textColor: const Color(0xFFE99C9C),
                  ),
                ),
```

- [ ] **Step 6: Add the `_handleDeleteAccount` method**

In the same file, the class currently ends with `_handleSignOut` immediately followed by the closing `}` of `SettingsPage` (the very end of the file). Replace:

```dart
      if (!context.mounted) return;

      // The global BlocListener<SessionCubit> in RootContext resets
      // navigation back to the root screen (WelcomePage) once the session
      // flips to Unauthenticated -- nothing to navigate here.
      await context.read<SessionCubit>().logout();
    }
  }
}
```

with:

```dart
      if (!context.mounted) return;

      // The global BlocListener<SessionCubit> in RootContext resets
      // navigation back to the root screen (WelcomePage) once the session
      // flips to Unauthenticated -- nothing to navigate here.
      await context.read<SessionCubit>().logout();
    }
  }

  Future<void> _handleDeleteAccount(BuildContext context, Locale locale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        title: Text(
          AppStrings.tr(locale, AppStrings.deleteAccountConfirmTitle),
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          AppStrings.tr(locale, AppStrings.deleteAccountConfirmMessage),
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppStrings.tr(locale, AppStrings.cancel),
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppStrings.tr(locale, AppStrings.delete),
              style: GoogleFonts.inter(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      // The global BlocListener<SessionCubit> in RootContext resets
      // navigation back to the root screen (WelcomePage) once the session
      // flips to Unauthenticated -- nothing to navigate here.
      await context.read<SessionCubit>().deleteAccount();
      if (!context.mounted) return;
      await context.di.notes.repository.wipeAllLocalData();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.tr(locale, AppStrings.deleteAccountFailed)),
        ),
      );
    }
  }
}
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test test/presentation/pages/settings_page_test.dart --concurrency=1`
Expected: PASS — all tests, including the new ones.

- [ ] **Step 8: Confirm no remaining references to the removed string key**

Run: `grep -rn "featureRequest" lib/ test/`
Expected: no output.

- [ ] **Step 9: Run the full frontend test suite and analyzer**

Run: `flutter test --concurrency=1`
Expected: PASS, 0 failures.

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 10: Commit**

```bash
git add lib/presentation/pages/settings_page.dart test/presentation/pages/settings_page_test.dart
git commit -m "feat(settings): wire up Terms of Use, Privacy Policy, and Delete Account; remove Feature Request"
```

---

### Task 8: Final verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full backend test suite**

Run: `cd backend && python -m pytest -v`
Expected: PASS, 0 failures. (Needs Postgres running per project convention — `docker compose up -d` first if not already up. The suite also runs fine against the default in-memory SQLite test config with no extra setup, per `conftest.py`.)

- [ ] **Step 2: Run the full frontend test suite**

Run: `flutter test --concurrency=1`
Expected: PASS, 0 failures.

- [ ] **Step 3: Run the analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Manual smoke test (optional but recommended)**

Start the backend (`docker compose up -d && cd backend && uvicorn app.main:app --reload`) and run the app. Register a test account, add a note and a folder, open Settings:
- Tap Terms of Use and Privacy Policy — confirm both open a scrollable page with real text and a working back button.
- Confirm the Feature Request row is gone.
- Tap Delete Account, confirm, and verify the app returns to the Welcome/guest screen with an empty local diary.
- Check the backend (or Railway dashboard) to confirm the account and its data are gone server-side.

No further commit for this task — it's verification of the work already committed in Tasks 1-7.
