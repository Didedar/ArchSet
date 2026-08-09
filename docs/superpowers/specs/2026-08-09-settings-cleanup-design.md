# Settings Cleanup: Legal Docs, Feature Request Removal, Delete Account

**Date:** 2026-08-09
**Status:** Approved, ready for planning
**Scope note:** This is sub-project 1 of 2 requested together. Sub-project 2
(Google/Apple Sign-In) was scoped as a separate, much larger effort — new
backend OAuth endpoints, a User schema migration, native SDK integration, and
real credentials from the user's Apple/Google developer accounts — and was
explicitly out of scope here. **Update:** the user later decided against
building it (didn't want to take on the OAuth credential setup) and asked to
remove the dead Google/Apple buttons instead. See
`docs/superpowers/specs/2026-08-09-remove-social-signin-buttons-design.md` —
sub-project 2 is closed, not pending.

## Overview

`SettingsPage` (`lib/presentation/pages/settings_page.dart`) currently has
four rows that are non-functional stubs: Terms of Use, Privacy Policy,
Feature Request, and Delete Account (all `onTap: () {} // TODO`). This spec
covers making three of them real and removing the fourth:

1. Delete Account — backend endpoint + frontend wiring, hard delete,
   immediate, wipes local data too.
2. Privacy Policy / Terms of Use — in-app screens with real English-only
   draft content (not a URL launch).
3. Feature Request — removed entirely (row + localized strings).

## Out of scope

- Google/Apple Sign-In — abandoned, not deferred; see
  `docs/superpowers/specs/2026-08-09-remove-social-signin-buttons-design.md`.
- Localizing the legal text into ru/kk/zh (English only for now, per
  decision below).
- Soft-delete / grace-period account recovery.
- Password re-entry confirmation for delete (plain confirm dialog only).

## 1. Backend — Delete Account endpoint

Add `DELETE /api/v1/auth/me` to `backend/app/routers/auth.py`:

- Protected by the existing `get_current_user` dependency (same as the
  current `GET /me`).
- Loads the authenticated user's row and deletes it, then commits.
- SQLAlchemy's existing `cascade="all, delete-orphan"` on
  `User.folders` / `User.notes` / `User.artifacts` / `User.artifact_comments`
  (`backend/app/models/user.py:43-48`) handles removing all dependent rows —
  no new cascade logic needed.
- Returns `204 No Content` on success.
- No token blacklist/revocation list needed: `get_current_user`
  (`backend/app/utils/security.py:80-112`) re-loads the user row from the
  `sub` claim on every request. Once the row is gone, any lingering
  access/refresh token for that user simply stops resolving — it's revoked
  for free by the delete itself.

**Error handling:** no new error cases beyond what `get_current_user`
already raises (401 for invalid/expired/missing token). A delete on an
already-deleted user can't happen through normal use (the token would
already be rejected), so no extra guard is needed.

## 2. Frontend — Delete Account wiring

Follows the existing layered pattern already used for Sign Out
(`AuthService` → `AuthRepository` → `AuthBloc` → `SettingsPage`):

- **`AuthService.deleteAccount()`** (`lib/data/services/auth_service.dart`) —
  calls `DELETE $_baseUrl/auth/me` with the stored bearer token for the
  current backend origin.
- **`AuthRepository`** (`lib/domain/repositories/auth_repository.dart` +
  implementation) — gets a matching `deleteAccount()` method.
- **`AuthBloc`** — gets a new event, e.g. `AuthAccountDeleteRequested`.
  On handling it:
  1. Call `authRepository.deleteAccount()`.
  2. On success: clear secure-storage tokens for the current backend
     origin (same cleanup Sign Out already performs), **and** wipe the
     local drift/sqlite diary tables (Notes, Folders, and any other
     user-scoped tables) for a full local reset — per the decision that
     deleting the account should erase on-device data too, not convert it
     back to guest data.
  3. Emit a signed-out/guest state, same terminal state Sign Out reaches.
  4. On failure (network error, etc.): surface an error to the UI, do
     **not** clear local state — the account still exists server-side, so
     nothing local should change until the delete actually succeeds.
- **`SettingsPage`** (`settings_page.dart:437-454`) — the Delete Account
  row gets a destructive confirmation `AlertDialog` before dispatching
  the event: red "Delete Account" action button, message along the lines
  of "This will permanently delete your account and all your diary data.
  This cannot be undone." — stronger wording than the existing Sign Out
  dialog since this one is irreversible. On success, navigate back to the
  Welcome/guest screen (same destination Sign Out navigates to).

## 3. Privacy Policy / Terms of Use screens

A single reusable page widget — e.g. `LegalDocumentPage(title, body)` —
rendered as a scrollable pushed page matching the app's existing page
style (consistent with how `SettingsPage` itself is presented). Two call
sites replace the current stubs:

- `settings_page.dart:119-125` (Terms of Use) → pushes
  `LegalDocumentPage` with the Terms of Use text.
- `settings_page.dart:127-136` (Privacy Policy) → pushes
  `LegalDocumentPage` with the Privacy Policy text.

Content is English-only for now (per decision), stored as plain constants
(e.g. in a new `lib/core/legal/legal_text.dart` or similar — exact location
is a planning detail). No `url_launcher` dependency needed; no external
hosting. Draft text is in the Appendix below — reviewed and owned by the
user before merge, not a placeholder.

## 4. Remove Feature Request

Delete the row entirely (`settings_page.dart:138-147`), plus its now-unused
localized strings: `AppStrings.featureRequest` and its four translations in
`lib/core/localization/app_strings.dart` (en/ru/kk/zh, currently around
lines 294-301, 443-450, 590-597, 736-743 per the pre-change line numbers —
exact lines will shift once other edits land first). Not hidden, not
feature-flagged — fully removed, since there's no feedback mechanism behind
it to preserve.

## Testing approach

- **Backend:** a test for `DELETE /api/v1/auth/me` — deleting a user with
  existing folders/notes/artifacts confirms the cascade actually removes
  them (not just the user row), and confirms a subsequent request with the
  now-orphaned token gets 401.
- **Frontend:** `AuthBloc` test for `AuthAccountDeleteRequested` covering
  success (tokens cleared, local tables wiped, state transitions to
  signed-out) and failure (nothing local changes, error surfaced).
  Widget-level: the confirmation dialog appears and only proceeds on
  explicit confirm.
- Manual verification: register a test account, add a note/folder, delete
  the account, confirm the app returns to Welcome with an empty local
  diary, and confirm the row is gone from the server DB.

## Appendix: Draft legal text (English only)

### Privacy Policy

**Last updated: August 2026**

ArchSet ("the app", "we", "us") is an offline-first diary application for
archaeologists. This policy explains what information the app collects,
how it's used, and how you can delete it.

**Information we collect**

- **Account information:** if you create an account, we store your email
  address and a securely hashed password. You can also use the app fully
  offline as a guest, without an account — in that case we don't collect
  any account information at all.
- **Diary content:** notes, folders, photos, and audio recordings you
  create in the app, along with any location coordinates you attach to an
  archaeological find.
- **Sync data:** if you're signed in, your diary content is synced to our
  server so it's available across sessions and (in the future) devices.
  If you never sign in, your diary content stays on your device only.

**How we use AI features**

The app offers two transcription/rewriting modes, and the choice is
always yours:

- **Offline (Whisper):** audio is transcribed entirely on your device.
  Nothing is sent anywhere.
- **Online (Gemini):** if you choose this mode, the relevant audio or text
  is sent to Google's Gemini API for transcription or archaeological-text
  rewriting, subject to Google's own privacy terms. We don't use this data
  for anything beyond returning the result to you.

**Where your data is stored**

- Locally on your device, in an encrypted local database.
- Authentication tokens are stored using your device's secure storage
  (Keychain on iOS, Keystore on Android).
- If you're signed in, your synced diary content is stored on our
  Postgres database, hosted on Railway.

**Your rights**

You can delete your account and all associated data at any time from
Settings → Delete Account. This permanently and immediately removes your
account, your synced diary content, and everything associated with it
from our server — this action cannot be undone. If you'd rather make the
request by email, or have any other question about your data, contact us
at **sabyrhandarhan@gmail.com**.

**Children's privacy**

ArchSet is not directed at children under 13, and we don't knowingly
collect information from children under 13.

**Changes to this policy**

If this policy changes in a meaningful way, we'll update the "last
updated" date above. Continued use of the app after a change means you
accept the updated policy.

**Contact**

sabyrhandarhan@gmail.com

---

### Terms of Use

**Last updated: August 2026**

By using ArchSet, you agree to these terms.

**The service**

ArchSet is an offline-first diary application for archaeologists. You can
use it fully offline without an account (guest mode), or create an
account to sync your diary content to our server.

**Your content**

You own everything you create in the app — your notes, photos, audio
recordings, and any other diary content. By syncing content to our
server (when signed in), you grant us the limited right to store and
process that content solely for the purpose of providing the app's
features to you (sync, search, AI transcription/rewriting when you
choose to use it). We don't claim ownership of your content and we don't
use it for anything else.

**Acceptable use**

Don't use ArchSet to store or process unlawful content, or to attempt to
disrupt or abuse the service.

**AI features**

Transcription and text-rewriting features are provided for convenience.
They can make mistakes — always review AI-generated text before relying
on it for your records.

**Account and termination**

You can delete your account at any time from Settings → Delete Account,
which permanently removes your account and its synced data immediately.
We may suspend or terminate access for accounts that violate these terms.

**No warranty**

ArchSet is provided "as is," without warranty of any kind. We do
reasonable best efforts to keep the service available and your data
safe, but we don't guarantee uninterrupted availability or that the
service will be error-free.

**Changes to these terms**

If these terms change in a meaningful way, we'll update the "last
updated" date above. Continued use of the app after a change means you
accept the updated terms.

**Contact**

sabyrhandarhan@gmail.com
