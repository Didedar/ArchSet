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
