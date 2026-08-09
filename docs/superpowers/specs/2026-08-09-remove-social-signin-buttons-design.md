# Remove Google/Apple Sign-In Buttons

**Date:** 2026-08-09
**Status:** Approved, ready for planning

## Background

This was originally scoped as "sub-project 2" of the settings-cleanup work: add real Google and Apple Sign-In. During design, the user decided against building it — the OAuth credential setup (Google Cloud project + 3 client IDs, Apple Developer Services ID + capability) wasn't something they wanted to take on right now. Decision: instead of building social sign-in, remove the non-functional "Sign in with Google" / "Sign in with Apple" buttons that currently sit on the Welcome screen and do nothing when tapped, leaving Email sign-in and Continue as Guest as the only two entry points.

## Current state

`lib/presentation/auth/pages/welcome_page.dart` renders 4 items in a staggered fade/slide-in animation, top to bottom: "Sign in with Google" (`onPressed: () {}`, dead), "Sign in with Apple" (`onPressed: () {}`, dead), "Sign in with Email" (functional, navigates to `SignInEmailPage`), "Continue as Guest" (functional). The animation is driven by one `AnimationController` with 5 named `Animation` pairs (`_textOpacity`/`_textSlide`, `_btn1Opacity`/`_btn1Slide` for Google, `_btn2Opacity`/`_btn2Slide` for Apple, `_btn3Opacity`/`_btn3Slide` for Email, `_guestOpacity`/`_guestSlide`), each a `CurvedAnimation` over a different `Interval` of the same controller, staggering the entrance.

`AppStrings.signInGoogle`/`signInApple` (declared, in `allKeys`, translated into all 4 locales) are used only by these two buttons — confirmed via repo-wide search, nothing else references them. The icon assets (`assets/images/icon_google.png`, `icon_apple.png`) are likewise referenced only here.

No `AuthBloc` event, no package dependency (`google_sign_in`/`sign_in_with_apple`), and no platform config (iOS entitlement, `GoogleService-Info.plist`, etc.) exist for these buttons — they are pure UI shells with zero backing logic, confirmed during the earlier exploration for this sub-project.

## Design

### 1. `welcome_page.dart`

Remove the Google and Apple `_buildButton(...)` call sites (and their `FadeTransition`/`SlideTransition` wrappers) from the widget tree entirely — not hidden, not disabled.

Reuse the Google button's animation slot for the Email button, so the entrance sequence still reads as an intentional stagger (text → Email button → Guest) instead of leaving a visible gap where two buttons used to fade in first:
- Keep `_btn1Opacity`/`_btn1Slide` (currently Google's `Interval(0.2, 0.5)`), but point the Email button's `FadeTransition`/`SlideTransition` at them instead of `_btn3Opacity`/`_btn3Slide`.
- Delete `_btn2Opacity`/`_btn2Slide` (was Apple) and `_btn3Opacity`/`_btn3Slide` (was Email) entirely, along with their `initState` setup — they become unused once Email moves onto `_btn1`.
- `_guestOpacity`/`_guestSlide` (`Interval(0.75, 1.0)`) are untouched.
- Remove the now-redundant `SizedBox(height: 16)` spacers that separated Google/Apple/Email; keep the single spacer between the Email button and the Guest button.

### 2. `app_strings.dart`

Remove `signInGoogle`/`signInApple`: the two key declarations, their two `allKeys` entries, and their translations from all 4 locale maps (en/ru/kk/zh) — the same full-removal treatment `featureRequest` got in the settings-cleanup work, since nothing else references them.

### 3. Assets

`icon_google.png`/`icon_apple.png` are left on disk. Not code, low-cost to leave, and out of scope for this change (`pubspec.yaml`'s asset declaration is directory-level, not per-file, so leaving them doesn't affect the build).

### 4. Testing

New file `test/presentation/auth/pages/welcome_page_test.dart` (none exists today). Covers:
- Google/Apple sign-in text is not found anywhere on the page.
- The Email button is still present and still navigates to `SignInEmailPage` when tapped.
- The Continue as Guest button is still present.

No backend changes. No new dependencies. No platform config changes. This fully closes out what was previously scoped as "sub-project 2."
