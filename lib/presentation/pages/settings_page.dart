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

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Account state comes from SessionCubit, the single source of truth for
    // "who is using the app" (see its doc comment). Reading AuthBloc here was
    // wrong twice over: it stays at AuthInitial for guests *and* for a signed-
    // in user after a restart (nothing dispatches AuthCheckRequested any more
    // -- SessionCubit.bootstrap() restores the session instead), so both cases
    // rendered "Unknown" plus a Sign Out button.
    final session = context.watch<SessionCubit>().state;
    final user = session is SessionAuthenticated ? session.user : null;
    final isGuest = user == null;

    final themeMode = context.watch<ThemeBloc>().state.mode;
    final isDarkMode =
        themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final currentLocale = context.watch<LocaleBloc>().state.locale;

    final colorScheme = Theme.of(context).colorScheme;
    final textColor = colorScheme.onSurface;
    // We use a specific color for the container background in dark mode (2C2C2E)
    // In light mode, we might want white or a very light grey.
    // Using the AppTheme definitions: Dark Surface is 2C2C2E, Light Surface is White (or F2F2F7 scaffold)
    // Let's rely on Theme.of(context).cardColor or dialogBackgroundColor for containers
    final containerColor = Theme.of(context).dialogBackgroundColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: containerColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isGuest ? Icons.person_outline : Icons.person,
                      color: textColor.withOpacity(isGuest ? 0.5 : 0.9),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.tr(
                            currentLocale,
                            isGuest ? AppStrings.guestMode : AppStrings.hello,
                          ),
                          style: GoogleFonts.inter(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (!isGuest)
                          Text(
                            user.email,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(height: 6),
                        _buildAccountStatusChip(
                          context,
                          isGuest: isGuest,
                          locale: currentLocale,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Section 1: Information
              Container(
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(20),
                ),
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
              ),
              const SizedBox(height: 24),

              // Section 2: Preferences
              Container(
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    _buildMenuItem(
                      context,
                      icon: isDarkMode
                          ? Icons.wb_sunny_outlined
                          : Icons.wb_sunny,
                      text: AppStrings.tr(currentLocale, AppStrings.darkMode),
                      onTap: () {
                        context.read<ThemeBloc>().add(
                          ThemeModeChanged(!isDarkMode),
                        );
                      },
                      textColor: textColor,
                      trailing: Switch(
                        value: isDarkMode,
                        onChanged: (val) {
                          context.read<ThemeBloc>().add(ThemeModeChanged(val));
                        },
                        activeColor: Colors.white,
                        activeTrackColor: Colors.green,
                      ),
                    ),
                    _buildDivider(context),
                    _buildMenuItem(
                      context,
                      icon: Icons.language,
                      text: AppStrings.tr(currentLocale, AppStrings.language),
                      onTap: () => _showLanguageDialog(context, currentLocale),
                      textColor: textColor,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // The value sits in a nested Row, and a Row is what
                          // overflows -- a Text on its own would just clip.
                          // So the shrinking has to be asked for here.
                          Flexible(
                            child: Text(
                              _getLanguageName(currentLocale.languageCode),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: textColor.withOpacity(0.5),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: textColor.withOpacity(0.5),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section: Transcription
              BlocBuilder<TranscriptionBloc, TranscriptionState>(
                builder: (context, transcriptionState) {
                  final transcriptionBloc = context.read<TranscriptionBloc>();

                  return Container(
                    decoration: BoxDecoration(
                      color: containerColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        _buildMenuItem(
                          context,
                          icon: Icons.record_voice_over_outlined,
                          text: AppStrings.tr(
                            currentLocale,
                            AppStrings.transcriptionMode,
                          ),
                          onTap: () {},
                          textColor: textColor,
                        ),
                        _buildDivider(context),

                        // Engine Selection
                        RadioListTile<TranscriptionEngine>(
                          title: Text(
                            AppStrings.tr(
                              currentLocale,
                              AppStrings.onlineGemini,
                            ),
                            style: GoogleFonts.inter(color: textColor),
                          ),
                          value: TranscriptionEngine.gemini,
                          groupValue: transcriptionState.engine,
                          onChanged: (val) => transcriptionBloc.add(
                            TranscriptionEngineChanged(val!),
                          ),
                          activeColor: const Color(0xFFD4F932),
                        ),
                        RadioListTile<TranscriptionEngine>(
                          title: Text(
                            AppStrings.tr(
                              currentLocale,
                              AppStrings.offlineWhisper,
                            ),
                            style: GoogleFonts.inter(color: textColor),
                          ),
                          value: TranscriptionEngine.whisper,
                          groupValue: transcriptionState.engine,
                          onChanged: (val) => transcriptionBloc.add(
                            TranscriptionEngineChanged(val!),
                          ),
                          activeColor: const Color(0xFFD4F932),
                        ),

                        if (transcriptionState.engine ==
                            TranscriptionEngine.whisper) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text(
                              AppStrings.tr(
                                currentLocale,
                                AppStrings.downloadWhisperDesc,
                              ),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: textColor.withOpacity(0.6),
                              ),
                            ),
                          ),
                          if (!transcriptionState.isModelDownloaded &&
                              !transcriptionState.isDownloading)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: ElevatedButton(
                                onPressed: () => transcriptionBloc.add(
                                  const TranscriptionModelDownloadRequested(),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD4F932),
                                  foregroundColor: Colors.black,
                                ),
                                child: Text(
                                  AppStrings.tr(
                                    currentLocale,
                                    AppStrings.downloadModel,
                                  ),
                                ),
                              ),
                            ),
                          if (transcriptionState.isDownloading)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  LinearProgressIndicator(
                                    value: transcriptionState.downloadProgress,
                                    color: const Color(0xFFD4F932),
                                    backgroundColor: Colors.grey[800],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${(transcriptionState.downloadProgress * 100).toInt()}%',
                                    style: GoogleFonts.inter(
                                      color: textColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (transcriptionState.isModelDownloaded)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      AppStrings.tr(
                                        currentLocale,
                                        AppStrings.modelDownloaded,
                                      ),
                                      style: GoogleFonts.inter(
                                        color: Colors.green,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Section 3: Account.
              //
              // A guest has no id, no email, nothing to sign out of and no
              // account to delete -- showing those rows (filled with
              // "Unknown") is what made the app look signed-in when it wasn't.
              // They get a sign-in prompt instead.
              if (isGuest)
                _buildGuestCard(
                  context,
                  locale: currentLocale,
                  containerColor: containerColor,
                  textColor: textColor,
                )
              else ...[
                Container(
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _buildMenuItem(
                        context,
                        icon: Icons.person,
                        text: AppStrings.tr(currentLocale, AppStrings.userId),
                        onTap: () {},
                        textColor: textColor,
                        trailing: Text(
                          user.id,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: textColor.withOpacity(0.5),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      _buildDivider(context),
                      _buildMenuItem(
                        context,
                        icon: Icons.email_outlined,
                        text: AppStrings.tr(currentLocale, AppStrings.email),
                        onTap: () {},
                        textColor: textColor,
                        trailing: Text(
                          user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: textColor.withOpacity(0.5),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      _buildDivider(context),
                      _buildMenuItem(
                        context,
                        icon: Icons.logout,
                        text: AppStrings.tr(currentLocale, AppStrings.signOut),
                        onTap: () => _handleSignOut(context, currentLocale),
                        textColor: textColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

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
              ],
              const SizedBox(height: 40),

              // Home Indicator Area
              Center(
                child: Container(
                  width: 134,
                  height: 5,
                  decoration: BoxDecoration(
                    color: textColor,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// At-a-glance "do I have an account?" badge, so the answer doesn't depend
  /// on the user reading an email address that may or may not be there.
  Widget _buildAccountStatusChip(
    BuildContext context, {
    required bool isGuest,
    required Locale locale,
  }) {
    final color = isGuest ? const Color(0xFFE0A030) : const Color(0xFF2E9E5B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isGuest ? Icons.person_off_outlined : Icons.verified_user_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          // Flexible even though the row is MainAxisSize.min: asking for the
          // natural width is not the same as staying inside what the parent
          // offers. On a 320pt phone the Kazakh label ran 11pt past the edge
          // of the header column.
          Flexible(
            child: Text(
              AppStrings.tr(
                locale,
                isGuest ? AppStrings.noAccount : AppStrings.signedIn,
              ),
              style: GoogleFonts.inter(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Replaces the account rows for guests: explains that data is local-only
  /// and offers the way out of guest mode.
  Widget _buildGuestCard(
    BuildContext context, {
    required Locale locale,
    required Color containerColor,
    required Color textColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 20,
                color: textColor.withOpacity(0.7),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppStrings.tr(locale, AppStrings.guestMode),
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.tr(locale, AppStrings.guestModeDescription),
            style: GoogleFonts.inter(
              color: textColor.withOpacity(0.6),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          // Sharing is visible but locked rather than hidden: a guest should
          // know the feature exists and what it costs them. Membership needs
          // a user id, and a guest has none -- this is not an implementation
          // limit but what sharing means.
          Row(
            children: [
              Icon(
                Icons.group_outlined,
                size: 18,
                color: textColor.withOpacity(0.4),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppStrings.tr(locale, AppStrings.sharingNeedsAccount),
                  style: GoogleFonts.inter(
                    color: textColor.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const SignInEmailPage(),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFff6d00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.login, size: 18),
              label: Text(
                AppStrings.tr(locale, AppStrings.signInOrCreateAccount),
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 64, right: 0),
      child: Divider(height: 1, color: Theme.of(context).dividerColor),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    Color? color,
    Color? textColor,
    Widget? trailing,
  }) {
    final effectiveColor = color ?? Theme.of(context).iconTheme.color;
    final effectiveTextColor =
        textColor ?? Theme.of(context).textTheme.bodyLarge?.color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        width: double.infinity,
        child: Row(
          children: [
            Icon(icon, color: effectiveColor, size: 24),
            const SizedBox(width: 16),
            // Both sides have to bend, and neither may take everything.
            //
            // A bare label with a Spacer overflowed: it claimed its natural
            // width and shoved the trailing widget off the edge. Making only
            // the label Expanded was worse -- an unbounded trailing (the user
            // id is a 36-character uuid) was measured first and left the label
            // nothing, so "User ID" came out stacked one letter per line.
            //
            // Flexible for the label so it takes what it needs and no more,
            // Expanded for the value so it fills the rest and ends flush right
            // the way the Spacer used to make it.
            Flexible(
              child: Text(
                text,
                style: GoogleFonts.inter(
                  color: effectiveTextColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: trailing,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'ru':
        return 'Русский';
      case 'kk':
        return 'Қазақша';
      case 'zh':
        return '中文';
      case 'en':
      default:
        return 'English';
    }
  }

  void _showLanguageDialog(BuildContext context, Locale locale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        title: Text(
          AppStrings.tr(locale, AppStrings.language),
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(context, 'English', 'en'),
            _buildLanguageOption(context, 'Русский', 'ru'),
            _buildLanguageOption(context, 'Қазақша', 'kk'),
            _buildLanguageOption(context, '中文', 'zh'),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(BuildContext context, String name, String code) {
    return ListTile(
      title: Text(
        name,
        style: GoogleFonts.inter(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      onTap: () {
        context.read<LocaleBloc>().add(LocaleChanged(code));
        Navigator.pop(context);
      },
    );
  }

  Future<void> _handleSignOut(BuildContext context, Locale locale) async {
    // Signing out while entries are still unsent strands them: the rows stay
    // in SQLite, but `ownerKey` scoping hides them until this same account
    // signs back in, so from the user's side a day of field notes simply
    // disappears. Warn, don't block -- leaving is their call to make, just
    // not blind.
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
              child: Text(
                AppStrings.tr(locale, AppStrings.cancel),
                style: GoogleFonts.inter(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
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

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        title: Text(
          AppStrings.tr(locale, AppStrings.signOutConfirmTitle),
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          AppStrings.tr(locale, AppStrings.signOutConfirmMessage),
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
              AppStrings.tr(locale, AppStrings.confirm),
              style: GoogleFonts.inter(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        // Best-effort: offline data stays local and syncs later, so logout
        // must never block on this. SyncOffline/SyncIdle are terminal too
        // (offline/unreachable and guest/no-op sync never reach
        // Success/Failure), and the timeout is a safety net for any sync
        // that ends without emitting a terminal state at all -- either way
        // logout always proceeds.
        final syncBloc = context.read<SyncBloc>();
        final syncFinished = syncBloc.stream.firstWhere(
          (state) =>
              state is SyncSuccess ||
              state is SyncFailure ||
              state is SyncOffline ||
              state is SyncIdle,
        );
        syncBloc.add(const SyncRequested());
        await syncFinished.timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('Sync failed before logout: $e');
      }
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

    // Captured before the session call: once deleteAccount() succeeds, the
    // global BlocListener<SessionCubit> in RootContext pops navigation back
    // to WelcomePage, which can unmount this widget before wipeAllLocalData()
    // gets a chance to run -- capturing the repository reference now means
    // the wipe still happens regardless of whether that leaves `context`
    // usable afterward.
    final notesRepository = context.di.notes.repository;

    try {
      // The global BlocListener<SessionCubit> in RootContext resets
      // navigation back to the root screen (WelcomePage) once the session
      // flips to Unauthenticated -- nothing to navigate here.
      await context.read<SessionCubit>().deleteAccount();
      await notesRepository.wipeAllLocalData();
    } catch (e) {
      debugPrint('Delete account failed: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.tr(locale, AppStrings.deleteAccountFailed)),
        ),
      );
    }
  }
}
