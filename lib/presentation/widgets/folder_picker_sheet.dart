import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/localization/app_strings.dart';
import '../providers/notes_provider.dart';
import 'create_folder_dialog.dart';

/// Bottom sheet for selecting a destination folder
class FolderPickerSheet extends ConsumerStatefulWidget {
  final String? currentFolderId;
  final String noteTitle;

  const FolderPickerSheet({
    super.key,
    this.currentFolderId,
    required this.noteTitle,
  });

  @override
  ConsumerState<FolderPickerSheet> createState() => _FolderPickerSheetState();
}

class _FolderPickerSheetState extends ConsumerState<FolderPickerSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(foldersStreamProvider);
    final folderCountsAsync = ref.watch(folderNoteCountsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.tr(ref, AppStrings.moveToFolder),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '"${widget.noteTitle}"',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),

            Divider(
              color: theme.colorScheme.onSurface.withOpacity(0.1),
              height: 1,
            ),

            // Folder list
            Flexible(
              child: foldersAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFE8B731)),
                ),
                error: (e, _) => Center(
                  child: Text(
                    AppStrings.tr(ref, AppStrings.errorLoadingFolders),
                    style: GoogleFonts.inter(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ),
                data: (folders) {
                  final counts = folderCountsAsync.valueOrNull ?? {};

                  return ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      // All Notes option
                      _FolderOption(
                        name: AppStrings.tr(ref, AppStrings.allNotes),
                        color: const Color(0xFFFF9000),
                        isSelected: widget.currentFolderId == null,
                        noteCount: counts['all_notes'] ?? 0,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(
                            context,
                            '',
                          ); // Empty string = null folderId
                        },
                        isAllNotes: true,
                      ),

                      // Separator
                      if (folders.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: Divider(
                            color: theme.colorScheme.onSurface.withOpacity(0.1),
                            height: 1,
                          ),
                        ),

                      // Folder options
                      ...folders.map((folder) {
                        final count = counts[folder.id] ?? 0;
                        return _FolderOption(
                          name: folder.name,
                          color: _parseColor(folder.color),
                          isSelected: widget.currentFolderId == folder.id,
                          noteCount: count,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.pop(context, folder.id);
                          },
                        );
                      }),

                      // Create new folder option
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                        child: _CreateFolderButton(
                          onTap: () async {
                            final newFolder = await showCreateFolderDialog(
                              context,
                            );
                            if (newFolder != null && mounted) {
                              Navigator.pop(context, newFolder.id);
                            }
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Bottom safe area
            SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String colorStr) {
    try {
      return Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFFE8B731);
    }
  }
}

class _FolderOption extends StatefulWidget {
  final String name;
  final Color color;
  final bool isSelected;
  final int noteCount;
  final VoidCallback onTap;
  final bool isAllNotes;

  const _FolderOption({
    required this.name,
    required this.color,
    required this.isSelected,
    required this.noteCount,
    required this.onTap,
    this.isAllNotes = false,
  });

  @override
  State<_FolderOption> createState() => _FolderOptionState();
}

class _FolderOptionState extends State<_FolderOption> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _isHovered || widget.isSelected
                ? widget.color.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: widget.isSelected
                ? Border.all(color: widget.color, width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              // Icon
              if (widget.isAllNotes)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.note_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                )
              else
                SvgPicture.string(
                  _getFolderSvg(widget.color),
                  width: 36,
                  height: 36,
                ),
              const SizedBox(width: 12),

              // Name
              Expanded(
                child: Text(
                  widget.name,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
              ),

              // Note count
              Text(
                '${widget.noteCount}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: textColor.withOpacity(0.5),
                ),
              ),

              // Checkmark if selected
              if (widget.isSelected) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_circle, color: widget.color, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getFolderSvg(Color color) {
    final colorHex =
        '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
    return '''<svg width="36" height="36" viewBox="0 0 45 45" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M7.5 37.5C6.46875 37.5 5.58625 37.1331 4.8525 36.3994C4.11875 35.6656 3.75125 34.7825 3.75 33.75V11.25C3.75 10.2188 4.1175 9.33625 4.8525 8.6025C5.5875 7.86875 6.47 7.50125 7.5 7.5H18.75L22.5 11.25H37.5C38.5312 11.25 39.4144 11.6175 40.1494 12.3525C40.8844 13.0875 41.2513 13.97 41.25 15V33.75C41.25 34.7812 40.8831 35.6644 40.1494 36.3994C39.4156 37.1344 38.5325 37.5012 37.5 37.5H7.5Z" fill="$colorHex" />
</svg>''';
  }
}

class _CreateFolderButton extends StatefulWidget {
  final VoidCallback onTap;

  const _CreateFolderButton({required this.onTap});

  @override
  State<_CreateFolderButton> createState() => _CreateFolderButtonState();
}

class _CreateFolderButtonState extends State<_CreateFolderButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // If I use withValues, I should use the correct method from Color.
    // .withValues is Dart 3.2? or ui.Color?
    // Using .withOpacity for compatibility if needed, but Flutter 3.22 uses withValues?
    // I will stick to .withOpacity or colors with opacity manually if I know the hex.
    // The previous code used .withValues(alpha: ...) which suggests newer Flutter SDK.

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _isHovered
                ? theme.colorScheme.onSurface.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.onSurface.withOpacity(0.1),
              width: 1,
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Consumer(
                builder: (context, ref, child) {
                  return const Icon(
                    Icons.add,
                    color: Color(0xFFE8B731),
                    size: 20,
                  ); // Keep gold/orange for action
                },
              ),
              const SizedBox(width: 8),
              Consumer(
                builder: (context, ref, child) {
                  return Text(
                    AppStrings.tr(ref, AppStrings.createNewFolder),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      color: const Color(0xFFE8B731),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Show folder picker bottom sheet
/// Returns folder ID or empty string for "All Notes", null if dismissed
Future<String?> showFolderPicker(
  BuildContext context, {
  String? currentFolderId,
  required String noteTitle,
}) {
  final theme = Theme.of(context);
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor:
        Colors.transparent, // Sheet content handles background/rounding
    isScrollControlled: true,
    builder: (context) => FolderPickerSheet(
      currentFolderId: currentFolderId,
      noteTitle: noteTitle,
    ),
  );
}
