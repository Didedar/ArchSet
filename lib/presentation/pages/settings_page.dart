import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/bloc/auth_bloc.dart';
import '../locale/bloc/locale_bloc.dart';
import '../providers/locale_provider.dart' as legacy_locale;
import '../sync/bloc/sync_bloc.dart';
import '../theme/bloc/theme_bloc.dart';
import '../transcription/bloc/transcription_bloc.dart';
import '../../core/localization/app_strings.dart';
import '../auth/pages/welcome_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;

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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.tr(ref, AppStrings.hello),
                        style: GoogleFonts.inter(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        user?.email ?? AppStrings.tr(ref, AppStrings.unknown),
                        style: GoogleFonts.inter(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
                      text: AppStrings.tr(ref, AppStrings.termsOfUse),
                      onTap: () {}, // TODO: Implement URL launch
                      textColor: textColor,
                    ),
                    _buildDivider(context),
                    _buildMenuItem(
                      context,
                      icon: Icons.privacy_tip_outlined,
                      text: AppStrings.tr(ref, AppStrings.privacyPolicy),
                      onTap: () {}, // TODO: Implement URL launch
                      textColor: textColor,
                    ),
                    _buildDivider(context),
                    _buildMenuItem(
                      context,
                      icon: Icons.card_membership_outlined,
                      text: AppStrings.tr(ref, AppStrings.featureRequest),
                      onTap: () {}, // TODO: Implement URL launch
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
                      text: AppStrings.tr(ref, AppStrings.darkMode),
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
                      text: AppStrings.tr(ref, AppStrings.language),
                      onTap: () => _showLanguageDialog(context, ref),
                      textColor: textColor,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getLanguageName(currentLocale.languageCode),
                            style: GoogleFonts.inter(
                              color: textColor.withOpacity(0.5),
                              fontSize: 14,
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
                            ref,
                            AppStrings.transcriptionMode,
                          ),
                          onTap: () {},
                          textColor: textColor,
                        ),
                        _buildDivider(context),

                        // Engine Selection
                        RadioListTile<TranscriptionEngine>(
                          title: Text(
                            AppStrings.tr(ref, AppStrings.onlineGemini),
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
                            AppStrings.tr(ref, AppStrings.offlineWhisper),
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
                                ref,
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
                                  AppStrings.tr(ref, AppStrings.downloadModel),
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
                                  Text(
                                    AppStrings.tr(
                                      ref,
                                      AppStrings.modelDownloaded,
                                    ),
                                    style: GoogleFonts.inter(
                                      color: Colors.green,
                                      fontSize: 12,
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

              // Section 3: User Info
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
                      text: AppStrings.tr(ref, AppStrings.userId),
                      onTap: () {},
                      textColor: textColor,
                      trailing: Text(
                        user?.id ?? AppStrings.tr(ref, AppStrings.unknown),
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
                      text: AppStrings.tr(ref, AppStrings.email),
                      onTap: () {},
                      textColor: textColor,
                      trailing: Text(
                        user?.email ?? AppStrings.tr(ref, AppStrings.unknown),
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
                      text: AppStrings.tr(ref, AppStrings.signOut),
                      onTap: () => _handleSignOut(context, ref),
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
                  text: AppStrings.tr(ref, AppStrings.deleteAccount),
                  color: const Color(0xFFE99C9C), // Keep red tint
                  onTap: () {}, // TODO: Implement delete account
                  textColor: const Color(0xFFE99C9C),
                ),
              ),
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
            Text(
              text,
              style: GoogleFonts.inter(
                color: effectiveTextColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (trailing != null) trailing,
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

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        title: Text(
          AppStrings.tr(ref, AppStrings.language),
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(context, ref, 'English', 'en'),
            _buildLanguageOption(context, ref, 'Русский', 'ru'),
            _buildLanguageOption(context, ref, 'Қазақша', 'kk'),
            _buildLanguageOption(context, ref, '中文', 'zh'),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    WidgetRef ref,
    String name,
    String code,
  ) {
    return ListTile(
      title: Text(
        name,
        style: GoogleFonts.inter(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      onTap: () {
        context.read<LocaleBloc>().add(LocaleChanged(code));
        // Dual-write: AppStrings.tr(ref, ...) (used across ~11 not-yet-
        // migrated pages) still reads the legacy Riverpod localeProvider
        // directly, so it needs updating too or those pages would show
        // stale-language text until restart. Remove once AppStrings.tr
        // no longer depends on Riverpod.
        ref.read(legacy_locale.localeProvider.notifier).setLocale(code);
        Navigator.pop(context);
      },
    );
  }

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        title: Text(
          AppStrings.tr(ref, AppStrings.signOutConfirmTitle),
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          AppStrings.tr(ref, AppStrings.signOutConfirmMessage),
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppStrings.tr(ref, AppStrings.cancel),
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppStrings.tr(ref, AppStrings.confirm),
              style: GoogleFonts.inter(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        final syncBloc = context.read<SyncBloc>();
        final syncFinished = syncBloc.stream.firstWhere(
          (state) => state is SyncSuccess || state is SyncFailure,
        );
        syncBloc.add(const SyncRequested());
        await syncFinished;
      } catch (e) {
        debugPrint('Sync failed before logout: $e');
      }
      if (!context.mounted) return;

      final authBloc = context.read<AuthBloc>();
      final loggedOut = authBloc.stream.firstWhere(
        (state) => state is AuthUnauthenticated,
      );
      authBloc.add(const AuthLogoutRequested());
      await loggedOut;

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const WelcomePage()),
          (route) => false,
        );
      }
    }
  }
}
