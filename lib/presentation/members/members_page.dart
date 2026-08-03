import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/localization/app_strings.dart';
import '../../data/services/members_service.dart';
import '../locale/bloc/locale_bloc.dart';

/// Who a dig site is shared with, and how to change that.
///
/// Everything here needs a connection -- membership is the one part of
/// collaboration that cannot work offline. The page says so plainly rather
/// than failing silently in a trench.
class MembersPage extends StatefulWidget {
  const MembersPage({
    required this.folderId,
    required this.folderName,
    required this.isOwner,
    required this.service,
    super.key,
  });

  final String folderId;
  final String folderName;

  /// Only the owner may invite or remove. Enforced on the server too -- this
  /// just avoids offering a button that would be refused.
  final bool isOwner;

  final MembersService service;

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  final _emailController = TextEditingController();

  List<DigSiteMember>? _members;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final members = await widget.service.listMembers(widget.folderId);
      if (mounted) setState(() => _members = members);
    } catch (_) {
      if (mounted) setState(() => _members = const []);
    }
  }

  String _messageFor(InviteFailure reason, Locale locale) =>
      AppStrings.tr(locale, switch (reason) {
        InviteFailure.unknownEmail => AppStrings.inviteUnknownEmail,
        InviteFailure.notOwner => AppStrings.inviteNotOwner,
        InviteFailure.offline => AppStrings.inviteOffline,
        InviteFailure.unknown => AppStrings.inviteFailed,
      });

  Future<void> _invite(Locale locale) async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.invite(widget.folderId, email);
      _emailController.clear();
      await _load();
    } on InviteException catch (e) {
      if (mounted) setState(() => _error = _messageFor(e.reason, locale));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(DigSiteMember member) async {
    setState(() => _busy = true);
    try {
      await widget.service.revoke(widget.folderId, member.userId);
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<LocaleBloc>().state.locale;
    final onSurface = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Text(
          AppStrings.tr(locale, AppStrings.members),
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.folderName,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 20),

            if (widget.isOwner) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: AppStrings.tr(
                          locale,
                          AppStrings.inviteByEmail,
                        ),
                        border: const OutlineInputBorder(),
                        errorText: _error,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _busy ? null : () => _invite(locale),
                    child: Text(AppStrings.tr(locale, AppStrings.inviteMember)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            if (_members == null)
              const Center(child: CircularProgressIndicator())
            else if (_members!.isEmpty)
              Text(
                AppStrings.tr(locale, AppStrings.noMembersYet),
                style: GoogleFonts.inter(
                  color: onSurface.withValues(alpha: 0.6),
                ),
              )
            else
              for (final member in _members!)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text(
                    member.email,
                    style: GoogleFonts.inter(color: onSurface),
                  ),
                  trailing: widget.isOwner
                      ? TextButton(
                          onPressed: _busy ? null : () => _revoke(member),
                          child: Text(
                            AppStrings.tr(locale, AppStrings.removeMember),
                            style: GoogleFonts.inter(color: Colors.redAccent),
                          ),
                        )
                      : null,
                ),
          ],
        ),
      ),
    );
  }
}
