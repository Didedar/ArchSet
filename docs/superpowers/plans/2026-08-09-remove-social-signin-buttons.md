# Remove Google/Apple Sign-In Buttons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the non-functional "Sign in with Google" / "Sign in with Apple" buttons from the Welcome screen, leaving Email sign-in and Continue as Guest as the only entry points.

**Architecture:** Delete the two dead `_buildButton(...)` call sites and their now-unused animation tweens from `WelcomePage`, reusing the Google button's animation slot for the Email button so the entrance stagger still reads as intentional. Then remove the now-fully-unused `signInGoogle`/`signInApple` localization keys.

**Tech Stack:** Flutter, flutter_bloc, mocktail/bloc_test.

**Spec:** `docs/superpowers/specs/2026-08-09-remove-social-signin-buttons-design.md`

---

## File Structure

- Modify: `lib/presentation/auth/pages/welcome_page.dart` — remove the Google/Apple buttons and their animation tweens
- Create: `test/presentation/auth/pages/welcome_page_test.dart` — first test coverage this page has ever had
- Modify: `lib/core/localization/app_strings.dart` — remove `signInGoogle`/`signInApple` (done second, so nothing ever references a key that doesn't exist)

---

### Task 1: Remove the Google/Apple buttons from `WelcomePage`

**Files:**
- Modify: `lib/presentation/auth/pages/welcome_page.dart`
- Create: `test/presentation/auth/pages/welcome_page_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/presentation/auth/pages/welcome_page_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:archset_r2/core/localization/app_strings.dart';
import 'package:archset_r2/presentation/auth/bloc/auth_bloc.dart';
import 'package:archset_r2/presentation/auth/pages/sign_in_email_page.dart';
import 'package:archset_r2/presentation/auth/pages/welcome_page.dart';
import 'package:archset_r2/presentation/locale/bloc/locale_bloc.dart';
import 'package:archset_r2/presentation/session/bloc/session_cubit.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockLocaleBloc extends MockBloc<LocaleEvent, LocaleState>
    implements LocaleBloc {}

class _MockSessionCubit extends MockCubit<AppSession> implements SessionCubit {}

void main() {
  late _MockAuthBloc authBloc;
  late _MockLocaleBloc localeBloc;
  late _MockSessionCubit sessionCubit;

  setUp(() {
    authBloc = _MockAuthBloc();
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: const AuthInitial(),
    );

    localeBloc = _MockLocaleBloc();
    whenListen(
      localeBloc,
      const Stream<LocaleState>.empty(),
      initialState: const LocaleState(Locale('en')),
    );

    sessionCubit = _MockSessionCubit();
    whenListen(
      sessionCubit,
      const Stream<AppSession>.empty(),
      initialState: const SessionGuest(),
    );
  });

  Future<void> pumpWelcomePage(WidgetTester tester) {
    return tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<LocaleBloc>.value(value: localeBloc),
          BlocProvider<SessionCubit>.value(value: sessionCubit),
        ],
        child: const MaterialApp(home: WelcomePage()),
      ),
    );
  }

  const locale = Locale('en');
  String s(String key) => AppStrings.tr(locale, key);

  testWidgets('does not show Google or Apple sign-in buttons', (
    tester,
  ) async {
    await pumpWelcomePage(tester);
    await tester.pumpAndSettle();

    expect(find.text('Sign in with Google'), findsNothing);
    expect(find.text('Sign in with Apple'), findsNothing);
  });

  testWidgets('the Email button is still present and opens SignInEmailPage', (
    tester,
  ) async {
    await pumpWelcomePage(tester);
    await tester.pumpAndSettle();

    final emailButton = find.text(s(AppStrings.signInEmail));
    expect(emailButton, findsOneWidget);

    await tester.tap(emailButton);
    await tester.pumpAndSettle();

    expect(find.byType(SignInEmailPage), findsOneWidget);
  });

  testWidgets('the Continue as Guest button is still present', (
    tester,
  ) async {
    await pumpWelcomePage(tester);
    await tester.pumpAndSettle();

    expect(find.text(s(AppStrings.continueAsGuest)), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/presentation/auth/pages/welcome_page_test.dart --concurrency=1`
Expected: FAIL — the first test fails because the Google/Apple buttons are still present (`find.text('Sign in with Google')` finds one widget, not none).

- [ ] **Step 3: Remove the unused animation fields**

Edit `lib/presentation/auth/pages/welcome_page.dart`. Replace:

```dart
  // Анимации
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _btn1Opacity;
  late Animation<Offset> _btn1Slide;
  late Animation<double> _btn2Opacity;
  late Animation<Offset> _btn2Slide;
  late Animation<double> _btn3Opacity;
  late Animation<Offset> _btn3Slide;
  late Animation<double> _guestOpacity;
  late Animation<Offset> _guestSlide;
```

with:

```dart
  // Анимации
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _btn1Opacity;
  late Animation<Offset> _btn1Slide;
  late Animation<double> _guestOpacity;
  late Animation<Offset> _guestSlide;
```

- [ ] **Step 4: Remove the unused animation setup in `initState`, repoint the remaining one at Email**

In the same file, replace:

```dart
    // 2. Кнопка Google
    _btn1Opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
      ),
    );
    _btn1Slide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
          ),
        );

    // 3. Кнопка Apple
    _btn2Opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
      ),
    );
    _btn2Slide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
          ),
        );

    // 4. Кнопка Email
    _btn3Opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 0.9, curve: Curves.easeOut),
      ),
    );
    _btn3Slide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.6, 0.9, curve: Curves.easeOut),
          ),
        );

    // 5. Гостевой режим
    _guestOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
      ),
    );
    _guestSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
          ),
        );
```

with:

```dart
    // 2. Кнопка Email
    _btn1Opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
      ),
    );
    _btn1Slide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
          ),
        );

    // 3. Гостевой режим
    _guestOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
      ),
    );
    _guestSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
          ),
        );
```

- [ ] **Step 5: Remove the Google/Apple buttons from the widget tree, repoint Email onto `_btn1`**

In the same file, replace:

```dart
                          // Кнопка 1
                          FadeTransition(
                            opacity: _btn1Opacity,
                            child: SlideTransition(
                              position: _btn1Slide,
                              child: _buildButton(
                                context,
                                text: AppStrings.tr(
                                  locale,
                                  AppStrings.signInGoogle,
                                ),
                                iconPath: 'assets/images/icon_google.png',
                                onPressed: () {},
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Кнопка 2
                          FadeTransition(
                            opacity: _btn2Opacity,
                            child: SlideTransition(
                              position: _btn2Slide,
                              child: _buildButton(
                                context,
                                text: AppStrings.tr(
                                  locale,
                                  AppStrings.signInApple,
                                ),
                                iconPath: 'assets/images/icon_apple.png',
                                onPressed: () {},
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Кнопка 3
                          FadeTransition(
                            opacity: _btn3Opacity,
                            child: SlideTransition(
                              position: _btn3Slide,
                              child: _buildButton(
                                context,
                                text: AppStrings.tr(
                                  locale,
                                  AppStrings.signInEmail,
                                ),
                                iconPath: 'assets/images/icon_email.png',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    CupertinoPageRoute(
                                      builder: (context) =>
                                          const SignInEmailPage(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),
```

with:

```dart
                          // Кнопка Email
                          FadeTransition(
                            opacity: _btn1Opacity,
                            child: SlideTransition(
                              position: _btn1Slide,
                              child: _buildButton(
                                context,
                                text: AppStrings.tr(
                                  locale,
                                  AppStrings.signInEmail,
                                ),
                                iconPath: 'assets/images/icon_email.png',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    CupertinoPageRoute(
                                      builder: (context) =>
                                          const SignInEmailPage(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/presentation/auth/pages/welcome_page_test.dart --concurrency=1`
Expected: PASS — all 3 tests.

- [ ] **Step 7: Run the full frontend test suite**

Run: `flutter test --concurrency=1`
Expected: PASS, 0 failures (baseline + 3 new tests).

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/auth/pages/welcome_page.dart test/presentation/auth/pages/welcome_page_test.dart
git commit -m "feat(auth): remove non-functional Google/Apple sign-in buttons"
```

---

### Task 2: Remove `signInGoogle`/`signInApple` from `AppStrings`

**Files:**
- Modify: `lib/core/localization/app_strings.dart`

- [ ] **Step 1: Remove the key declarations**

Edit `lib/core/localization/app_strings.dart`. Replace:

```dart
  static const String signInGoogle = 'sign_in_google';
  static const String signInApple = 'sign_in_apple';
  static const String signInEmail = 'sign_in_email';
```

with:

```dart
  static const String signInEmail = 'sign_in_email';
```

- [ ] **Step 2: Remove from `allKeys`**

Replace:

```dart
    signInGoogle,
    signInApple,
    signInEmail,
```

with:

```dart
    signInEmail,
```

- [ ] **Step 3: Remove from every locale table**

In the `'en'` map, replace:

```dart
      signInGoogle: 'Sign in with Google',
      signInApple: 'Sign in with Apple',
      signInEmail: 'Sign in with Email',
```

with:

```dart
      signInEmail: 'Sign in with Email',
```

In the `'ru'` map, replace:

```dart
      signInGoogle: 'Войти через Google',
      signInApple: 'Войти через Apple',
      signInEmail: 'Войти через Email',
```

with:

```dart
      signInEmail: 'Войти через Email',
```

In the `'kk'` map, replace:

```dart
      signInGoogle: 'Google арқылы кіру',
      signInApple: 'Apple арқылы кіру',
      signInEmail: 'Email арқылы кіру',
```

with:

```dart
      signInEmail: 'Email арқылы кіру',
```

In the `'zh'` map, replace:

```dart
      signInGoogle: '使用 Google 登录',
      signInApple: '使用 Apple 登录',
      signInEmail: '使用邮箱登录',
```

with:

```dart
      signInEmail: '使用邮箱登录',
```

- [ ] **Step 4: Run the localization tests**

Run: `flutter test test/core/localization/app_strings_test.dart --concurrency=1`
Expected: PASS — locale parity holds, nothing references the removed keys.

- [ ] **Step 5: Confirm nothing else references the removed keys**

Run: `grep -rn "signInGoogle\|signInApple" lib/ test/`
Expected: no output.

- [ ] **Step 6: Run the full frontend test suite and analyzer**

Run: `flutter test --concurrency=1`
Expected: PASS, 0 failures.

Run: `flutter analyze`
Expected: no new issues introduced by this change (this codebase has pre-existing `info`-level deprecation warnings elsewhere unrelated to this change — don't be alarmed by those, just confirm nothing new appears in the two files this task touched).

- [ ] **Step 7: Commit**

```bash
git add lib/core/localization/app_strings.dart
git commit -m "feat(i18n): remove unused sign_in_google/sign_in_apple strings"
```

---

## Manual verification (optional but recommended)

Run the app, open the Welcome screen: confirm only "Sign in with Email" and "Continue as Guest" are shown, the entrance animation still looks intentional (no visible gap or pause where the old buttons used to be), and tapping Email still opens the sign-in form.
