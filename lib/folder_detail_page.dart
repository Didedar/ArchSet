import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animations/animations.dart';
import 'core/localization/app_strings.dart';
import 'data/database/app_database.dart';
import 'diary_edit_page.dart';
import 'presentation/providers/notes_provider.dart';
import 'presentation/widgets/note_card.dart';
import 'presentation/widgets/empty_state.dart';
import 'presentation/widgets/folder_picker_sheet.dart';

/// Folder detail page showing all notes in a specific folder
class FolderDetailPage extends ConsumerStatefulWidget {
  final Folder folder;

  const FolderDetailPage({super.key, required this.folder});

  @override
  ConsumerState<FolderDetailPage> createState() => _FolderDetailPageState();
}

class _FolderDetailPageState extends ConsumerState<FolderDetailPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fabController;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  Color get _folderColor {
    try {
      return Color(int.parse(widget.folder.color.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFFE8B731);
    }
  }

  void _onFabPressed() {
    HapticFeedback.mediumImpact();
    _fabController.forward().then((_) => _fabController.reverse());

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            DiaryEditPage(initialFolderId: widget.folder.id),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 0.1);
          const end = Offset.zero;
          const curve = Curves.easeOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          var fadeAnimation = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));

          var scaleAnimation = Tween<double>(
            begin: 0.95,
            end: 1.0,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));

          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(
              position: offsetAnimation,
              child: ScaleTransition(scale: scaleAnimation, child: child),
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesInFolderProvider(widget.folder.id));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Hero(
              tag: 'folder-${widget.folder.id}',
              child: SvgPicture.string(
                _getFolderSvg(_folderColor),
                width: 28,
                height: 28,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.folder.name,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: theme.iconTheme.color),
            color: theme.cardColor,
            onSelected: (value) async {
              if (value == 'delete') {
                final confirm = await _confirmDelete();
                if (confirm == true && mounted) {
                  await ref
                      .read(notesRepositoryProvider)
                      .deleteFolder(widget.folder.id);
                  Navigator.pop(context);
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.tr(ref, AppStrings.deleteFolder),
                      style: GoogleFonts.inter(color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: notesAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFFE8B731)),
            ),
            error: (error, stack) => Center(
              child: Text(
                'Error: $error',
                style: GoogleFonts.inter(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
            data: (notes) {
              if (notes.isEmpty) {
                return EmptyState(
                  icon: Icons.note_add_outlined,
                  title: AppStrings.tr(ref, AppStrings.noNotesInFolder),
                  subtitle: AppStrings.tr(ref, AppStrings.tapToCreateNote),
                );
              }

              return ListView.builder(
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final note = notes[index];
                  return Dismissible(
                    key: Key(note.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (direction) async {
                      // Show options: delete or move
                      return await _showNoteOptions(note);
                    },
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    child: OpenContainer(
                      closedElevation: 0,
                      openElevation: 0,
                      closedColor: Colors.transparent,
                      openColor:
                          theme.scaffoldBackgroundColor, // Use theme background
                      transitionDuration: const Duration(milliseconds: 500),
                      closedBuilder: (context, action) {
                        return NoteCard(
                          note: note,
                          index: index,
                          onTap: action,
                          onLongPress: () => _showNoteContextMenu(note),
                          folderName: widget.folder.name,
                        );
                      },
                      openBuilder: (context, action) {
                        return DiaryEditPage(
                          noteId: note.id,
                          initialTitle: note.title,
                          initialContent: note.content,
                          initialFolderId: note.folderId,
                          initialAudioPath: note.audioPath,
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _fabController,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 - (_fabController.value * 0.1),
            child: Container(
              width: 63,
              height: 60,
              decoration: BoxDecoration(
                color: _folderColor,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: _folderColor.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: _onFabPressed,
                  child: const Center(
                    child: Icon(Icons.add, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Future<bool?> _showNoteOptions(Note note) async {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;

    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: textColor.withOpacity(0.2), // Auto-adapt indicator color
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.drive_file_move, color: textColor),
              title: Text(
                AppStrings.tr(ref, AppStrings.moveToFolder),
                style: GoogleFonts.inter(color: textColor),
              ),
              onTap: () async {
                Navigator.pop(context, false);
                final newFolderId = await showFolderPicker(
                  context,
                  currentFolderId: note.folderId,
                  noteTitle: note.title,
                );
                if (newFolderId != null) {
                  final folderId = newFolderId.isEmpty ? null : newFolderId;
                  await ref
                      .read(notesRepositoryProvider)
                      .moveNoteToFolder(note.id, folderId);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: Text(
                AppStrings.tr(ref, AppStrings.deleteNote),
                style: GoogleFonts.inter(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(context, true);
                ref.read(notesRepositoryProvider).deleteNote(note.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showNoteContextMenu(Note note) {
    _showNoteOptions(note);
  }

  Future<bool?> _confirmDelete() {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        title: Text(
          AppStrings.tr(
            ref,
            AppStrings.confirmDeleteFolder,
          ).replaceFirst('%s', widget.folder.name),
          style: GoogleFonts.inter(color: textColor),
        ),
        content: Text(
          AppStrings.tr(ref, AppStrings.notesMovedToAll),
          style: GoogleFonts.inter(color: textColor.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppStrings.tr(ref, AppStrings.cancel),
              style: GoogleFonts.inter(color: textColor.withOpacity(0.5)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppStrings.tr(ref, AppStrings.delete),
              style: GoogleFonts.inter(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  String _getFolderSvg(Color color) {
    final colorHex =
        '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
    return '''<svg width="28" height="28" viewBox="0 0 45 45" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M7.5 37.5C6.46875 37.5 5.58625 37.1331 4.8525 36.3994C4.11875 35.6656 3.75125 34.7825 3.75 33.75V11.25C3.75 10.2188 4.1175 9.33625 4.8525 8.6025C5.5875 7.86875 6.47 7.50125 7.5 7.5H18.75L22.5 11.25H37.5C38.5312 11.25 39.4144 11.6175 40.1494 12.3525C40.8844 13.0875 41.2513 13.97 41.25 15V33.75C41.25 34.7812 40.8831 35.6644 40.1494 36.3994C39.4156 37.1344 38.5325 37.5012 37.5 37.5H7.5Z" fill="$colorHex" />
</svg>''';
  }
}
