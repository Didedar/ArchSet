import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_strings.dart';
import '../../../data/models/artifact.dart';
import '../../../data/repository/artifacts_repository.dart';
import '../../locale/bloc/locale_bloc.dart';
import '../bloc/artifact_comments_bloc.dart';

/// Bottom sheet shown when an artifact pin is tapped: photo, coordinates,
/// Gemini analysis, and the comment thread.
///
/// Returns the note id via [Navigator.pop] when the user asks to open the
/// source note, so the caller decides how to navigate.
class ArtifactDetailSheet extends StatelessWidget {
  const ArtifactDetailSheet({
    super.key,
    required this.artifact,
    required this.repository,
  });

  final Artifact artifact;
  final ArtifactsRepository repository;

  /// Shows the sheet and resolves to the note id the user wants to open,
  /// or null if they just dismissed it.
  static Future<String?> show(
    BuildContext context, {
    required Artifact artifact,
    required ArtifactsRepository repository,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          ArtifactDetailSheet(artifact: artifact, repository: repository),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          ArtifactCommentsBloc(repository: repository, artifactId: artifact.id)
            ..add(const ArtifactCommentsSubscriptionRequested()),
      child: _ArtifactDetailView(artifact: artifact),
    );
  }
}

class _ArtifactDetailView extends StatefulWidget {
  const _ArtifactDetailView({required this.artifact});

  final Artifact artifact;

  @override
  State<_ArtifactDetailView> createState() => _ArtifactDetailViewState();
}

class _ArtifactDetailViewState extends State<_ArtifactDetailView> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _submitComment() {
    final body = _commentController.text.trim();
    if (body.isEmpty) return;
    context.read<ArtifactCommentsBloc>().add(ArtifactCommentAdded(body));
    _commentController.clear();
    _commentFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<LocaleBloc>().state.locale;
    final artifact = widget.artifact;

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const _DragHandle(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  children: [
                    _ArtifactPhoto(imagePath: artifact.imagePath),
                    const SizedBox(height: 16),
                    Text(
                      artifact.displayTitle ??
                          AppStrings.tr(locale, AppStrings.artifact),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Normally always true, since the sheet opens from a pin.
                    // Guarded anyway so a future caller can't crash on `!`.
                    if (artifact.hasLocation)
                      _MetaRow(
                        icon: Icons.location_on,
                        label: AppStrings.tr(locale, AppStrings.coordinates),
                        value:
                            '${artifact.latitude!.toStringAsFixed(5)}, '
                            '${artifact.longitude!.toStringAsFixed(5)}',
                      ),
                    _MetaRow(
                      icon: Icons.schedule,
                      label: AppStrings.tr(locale, AppStrings.photographed),
                      value: DateFormat.yMMMd(
                        locale.languageCode,
                      ).add_Hm().format(artifact.capturedAt),
                    ),
                    if (artifact.noteId != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () =>
                              Navigator.pop(context, artifact.noteId),
                          icon: const Icon(
                            Icons.description_outlined,
                            size: 18,
                          ),
                          label: Text(
                            artifact.noteTitle?.isNotEmpty == true
                                ? artifact.noteTitle!
                                : AppStrings.tr(locale, AppStrings.openNote),
                            style: const TextStyle(fontFamily: 'Inter'),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (artifact.isAnalyzed)
                      _AnalysisSections(artifact: artifact)
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          AppStrings.tr(locale, AppStrings.notAnalyzed),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: 'Inter',
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ),
                    const Divider(height: 32),
                    _CommentsSection(locale: locale),
                  ],
                ),
              ),
              _CommentComposer(
                controller: _commentController,
                focusNode: _commentFocus,
                hintText: AppStrings.tr(locale, AppStrings.addComment),
                onSubmit: _submitComment,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _ArtifactPhoto extends StatelessWidget {
  const _ArtifactPhoto({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<LocaleBloc>().state.locale;

    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.file(File(imagePath), fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ),
            ],
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          File(imagePath),
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          // The photo lives on the device that took it; a synced artifact
          // viewed elsewhere has metadata but no file.
          errorBuilder: (context, error, stackTrace) => Container(
            height: 200,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_not_supported_outlined,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.tr(locale, AppStrings.imageUnavailable),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'Inter',
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'Inter',
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'Inter'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders the four Gemini analysis sections, skipping any the model omitted.
class _AnalysisSections extends StatelessWidget {
  const _AnalysisSections({required this.artifact});

  final Artifact artifact;

  @override
  Widget build(BuildContext context) {
    final sections = <(String, Map<String, dynamic>?)>[
      ('Spatial Context', artifact.spatialContext),
      ('Physical Characteristics', artifact.physicalCharacteristics),
      ('Relational Context', artifact.relationalContext),
      ('Administrative Data', artifact.administrativeData),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (title, content) in sections)
          if (content != null && content.isNotEmpty)
            _AnalysisSection(title: title, content: content),
      ],
    );
  }
}

class _AnalysisSection extends StatelessWidget {
  const _AnalysisSection({required this.title, required this.content});

  final String title;
  final Map<String, dynamic> content;

  /// Converts Gemini's snake_case keys into readable labels.
  static String _formatKey(String key) => key
      .split('_')
      .map(
        (word) =>
            word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        ...content.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatKey(entry.key)}: ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'Inter',
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.value?.toString() ?? '—',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CommentsSection extends StatelessWidget {
  const _CommentsSection({required this.locale});

  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<ArtifactCommentsBloc, ArtifactCommentsState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.tr(locale, AppStrings.comments),
              style: theme.textTheme.titleSmall?.copyWith(
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            switch (state) {
              ArtifactCommentsLoadInProgress() ||
              ArtifactCommentsInitial() => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              ArtifactCommentsLoadFailure(:final message) => Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'Inter',
                  color: theme.colorScheme.error,
                ),
              ),
              ArtifactCommentsLoadSuccess(
                :final comments,
                :final actionError,
              ) =>
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (actionError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          actionError,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'Inter',
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    if (comments.isEmpty)
                      Text(
                        AppStrings.tr(locale, AppStrings.noComments),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'Inter',
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      )
                    else
                      ...comments.map(
                        (comment) =>
                            _CommentTile(comment: comment, locale: locale),
                      ),
                  ],
                ),
            },
          ],
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.locale});

  final ArtifactComment comment;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat.yMMMd(
                    locale.languageCode,
                  ).add_Hm().format(comment.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'Inter',
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            tooltip: AppStrings.tr(locale, AppStrings.deleteComment),
            onPressed: () => context.read<ArtifactCommentsBloc>().add(
              ArtifactCommentDeleted(comment.id),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        // Lift above the keyboard when it opens.
        8 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSubmit(),
                style: const TextStyle(fontFamily: 'Inter'),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(
                    fontFamily: 'Inter',
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: onSubmit,
              icon: const Icon(Icons.send, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
