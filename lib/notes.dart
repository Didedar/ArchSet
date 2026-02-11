import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animations/animations.dart';
import 'core/localization/app_strings.dart';
import 'data/database/app_database.dart';
import 'diary_edit_page.dart';
import 'folder_detail_page.dart';
import 'presentation/providers/notes_provider.dart';
import 'presentation/widgets/note_card.dart';
import 'presentation/widgets/empty_state.dart';
import 'presentation/widgets/loading_skeleton.dart';
import 'presentation/widgets/folder_card.dart';
import 'presentation/widgets/create_folder_dialog.dart';
import 'presentation/pages/settings_page.dart';

class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage>
    with SingleTickerProviderStateMixin {
  bool _isAllTabSelected = true;
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

  void _onFabPressed() {
    HapticFeedback.mediumImpact();
    _fabController.forward().then((_) => _fabController.reverse());

    if (!_isAllTabSelected) {
      // On Folders tab - create new folder
      showCreateFolderDialog(context);
    } else {
      // On All tab - create new note
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const DiaryEditPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 0.1);
            const end = Offset.zero;
            const curve = Curves.easeOut;

            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);

            var fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            );

            var scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            );

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
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesStreamProvider);
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final iconColor = theme.iconTheme.color ?? textColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppStrings.tr(ref, AppStrings.myNotes),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 25,
                      color: textColor,
                    ),
                  ),
                  // Settings Icon
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsPage(),
                        ),
                      );
                    },
                    child: SvgPicture.string(
                      '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M19.9 12.66C19.7397 12.4775 19.6513 12.2429 19.6513 12C19.6513 11.7571 19.7397 11.5225 19.9 11.34L21.18 9.90002C21.3211 9.74269 21.4086 9.54472 21.4302 9.33452C21.4518 9.12433 21.4062 8.9127 21.3 8.73002L19.3 5.27002C19.1949 5.08754 19.0349 4.94289 18.8428 4.8567C18.6506 4.77051 18.4362 4.74718 18.23 4.79002L16.35 5.17002C16.1108 5.21945 15.8617 5.17961 15.6499 5.05802C15.438 4.93643 15.278 4.7415 15.2 4.51002L14.59 2.68002C14.5229 2.4814 14.3951 2.30888 14.2246 2.18686C14.0542 2.06484 13.8496 1.99948 13.64 2.00002H9.64C9.42194 1.98864 9.20614 2.04894 9.02557 2.17173C8.845 2.29452 8.70958 2.47304 8.64 2.68002L8.08 4.51002C8.002 4.7415 7.84198 4.93643 7.63012 5.05802C7.41826 5.17961 7.16922 5.21945 6.93 5.17002L5 4.79002C4.80455 4.7624 4.6053 4.79324 4.42735 4.87866C4.2494 4.96407 4.1007 5.10025 4 5.27002L2 8.73002C1.89116 8.91067 1.84223 9.1211 1.86019 9.33124C1.87815 9.54138 1.96209 9.74046 2.1 9.90002L3.37 11.34C3.53032 11.5225 3.61874 11.7571 3.61874 12C3.61874 12.2429 3.53032 12.4775 3.37 12.66L2.1 14.1C1.96209 14.2596 1.87815 14.4587 1.86019 14.6688C1.84223 14.8789 1.89116 15.0894 2 15.27L4 18.73C4.1051 18.9125 4.26512 19.0571 4.45726 19.1433C4.64939 19.2295 4.86383 19.2529 5.07 19.21L6.95 18.83C7.18922 18.7806 7.43826 18.8204 7.65012 18.942C7.86198 19.0636 8.022 19.2585 8.1 19.49L8.71 21.32C8.77958 21.527 8.915 21.7055 9.09557 21.8283C9.27614 21.9511 9.49194 22.0114 9.71 22H13.71C13.9196 22.0006 14.1242 21.9352 14.2946 21.8132C14.4651 21.6912 14.5929 21.5186 14.66 21.32L15.27 19.49C15.348 19.2585 15.508 19.0636 15.7199 18.942C15.9317 18.8204 16.1808 18.7806 16.42 18.83L18.3 19.21C18.5062 19.2529 18.7206 19.2295 18.9128 19.1433C19.1049 19.0571 19.2649 18.9125 19.37 18.73L21.37 15.27C21.4762 15.0873 21.5218 14.8757 21.5002 14.6655C21.4786 14.4553 21.3911 14.2573 21.25 14.1L19.9 12.66ZM18.41 14L19.21 14.9L17.93 17.12L16.75 16.88C16.0298 16.7328 15.2806 16.8551 14.6446 17.2238C14.0086 17.5925 13.5301 18.1819 13.3 18.88L12.92 20H10.36L10 18.86C9.76986 18.1619 9.29138 17.5725 8.65541 17.2038C8.01943 16.8351 7.27022 16.7128 6.55 16.86L5.37 17.1L4.07 14.89L4.87 13.99C5.36196 13.44 5.63394 12.7279 5.63394 11.99C5.63394 11.2521 5.36196 10.54 4.87 9.99002L4.07 9.09002L5.35 6.89002L6.53 7.13002C7.25022 7.27724 7.99943 7.1549 8.63541 6.78622C9.27138 6.41753 9.74986 5.82818 9.98 5.13002L10.36 4.00002H12.92L13.3 5.14002C13.5301 5.83818 14.0086 6.42753 14.6446 6.79622C15.2806 7.1649 16.0298 7.28724 16.75 7.14002L17.93 6.90002L19.21 9.12002L18.41 10.02C17.9236 10.5688 17.655 11.2767 17.655 12.01C17.655 12.7433 17.9236 13.4513 18.41 14ZM11.64 8.00002C10.8489 8.00002 10.0755 8.23461 9.41772 8.67414C8.75992 9.11366 8.24724 9.73838 7.94448 10.4693C7.64173 11.2002 7.56252 12.0045 7.71686 12.7804C7.8712 13.5563 8.25217 14.269 8.81158 14.8284C9.37099 15.3879 10.0837 15.7688 10.8596 15.9232C11.6356 16.0775 12.4398 15.9983 13.1707 15.6955C13.9016 15.3928 14.5264 14.8801 14.9659 14.2223C15.4054 13.5645 15.64 12.7911 15.64 12C15.64 10.9392 15.2186 9.92174 14.4684 9.17159C13.7183 8.42144 12.7009 8.00002 11.64 8.00002ZM11.64 14C11.2444 14 10.8578 13.8827 10.5289 13.663C10.2 13.4432 9.94362 13.1308 9.79224 12.7654C9.64087 12.3999 9.60126 11.9978 9.67843 11.6098C9.7556 11.2219 9.94608 10.8655 10.2258 10.5858C10.5055 10.3061 10.8619 10.1156 11.2498 10.0384C11.6378 9.96128 12.0399 10.0009 12.4054 10.1523C12.7708 10.3036 13.0832 10.56 13.3029 10.8889C13.5227 11.2178 13.64 11.6045 13.64 12C13.64 12.5304 13.4293 13.0392 13.0542 13.4142C12.6791 13.7893 12.1704 14 11.64 14Z" fill="white" /> </svg>''',
                      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Search & Filter Row
              Row(
                children: [
                  // Search Button
                  _buildFilterButton(
                    context,
                    icon:
                        '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"> <path d="M16.893 16.92L19.973 20M19 11.5C19 13.4891 18.2098 15.3968 16.8033 16.8033C15.3968 18.2098 13.4891 19 11.5 19C9.51088 19 7.60322 18.2098 6.1967 16.8033C4.79018 15.3968 4 13.4891 4 11.5C4 9.51088 4.79018 7.60322 6.1967 6.1967C7.60322 4.79018 9.51088 4 11.5 4C13.4891 4 15.3968 4.79018 16.8033 6.1967C18.2098 7.60322 19 9.51088 19 11.5Z" stroke="#8C8C8C" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" /> </svg>''',
                    width: 38,
                  ),
                  const SizedBox(width: 12),

                  // "All" Tab
                  _buildTab(
                    context,
                    label: AppStrings.tr(ref, AppStrings.all),
                    isSelected: _isAllTabSelected,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _isAllTabSelected = true;
                      });
                    },
                    width: 38,
                  ),
                  const SizedBox(width: 12),

                  // "Folders" Tab
                  _buildTab(
                    context,
                    label: AppStrings.tr(ref, AppStrings.folders),
                    isSelected: !_isAllTabSelected,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _isAllTabSelected = false;
                      });
                    },
                    width: 81,
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Content Body
              Expanded(
                child: _isAllTabSelected
                    ? _buildAllNotes(notesAsync)
                    : _buildFoldersView(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _fabController,
        builder: (context, child) {
          final fabColor = theme.brightness == Brightness.dark
              ? Colors.white
              : theme.colorScheme.primaryContainer;
          final fabIconColor = theme.brightness == Brightness.dark
              ? Colors.black
              : theme.colorScheme.onPrimaryContainer;

          return Transform.scale(
            scale: 1.0 - (_fabController.value * 0.1),
            child: Container(
              width: 63,
              height: 60,
              decoration: BoxDecoration(
                color: fabColor,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
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
                  child: Center(
                    child: SvgPicture.string(
                      '''<svg width="31" height="31" viewBox="0 0 31 31" fill="none" xmlns="http://www.w3.org/2000/svg"> <path d="M14.8542 16.1458H7.75V14.8542H14.8542V7.75H16.1458V14.8542H23.25V16.1458H16.1458V23.25H14.8542V16.1458Z" fill="black" /> </svg>''',
                      colorFilter: ColorFilter.mode(
                        fabIconColor,
                        BlendMode.srcIn,
                      ),
                    ),
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

  Widget _buildFilterButton(
    BuildContext context, {
    required String icon,
    required double width,
  }) {
    return _FloatingWrapper(
      child: Container(
        width: width,
        height: 35,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(22),
        ),
        alignment: Alignment.center,
        child: SvgPicture.string(icon, width: 16, height: 16),
      ),
    );
  }

  Widget _buildTab(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required double width,
  }) {
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.surface; // White/Light usually
    final unselectedColor = theme.cardColor; // Dark grey/Off white
    final selectedTextColor = theme.colorScheme.onSurface; // Black/Dark
    final unselectedTextColor = theme.colorScheme.onSurface; // White/Dark

    // Refined logic for tab colors based on theme
    final bgColor = isSelected
        ? (theme.brightness == Brightness.dark ? Colors.white : Colors.black)
        : unselectedColor;
    final txtColor = isSelected
        ? (theme.brightness == Brightness.dark ? Colors.black : Colors.white)
        : unselectedTextColor;

    return _FloatingWrapper(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: width,
        height: isSelected ? 36 : 35,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(isSelected ? 19 : 22),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: isSelected ? 14 : 12,
            color: txtColor,
          ),
        ),
      ),
    );
  }

  Widget _buildAllNotes(AsyncValue<List<Note>> notesAsync) {
    final foldersAsync = ref.watch(foldersStreamProvider);

    // Build a map of folderId -> folderName for quick lookup
    final folderMap = <String, String>{};
    if (foldersAsync.hasValue) {
      for (final folder in foldersAsync.value!) {
        folderMap[folder.id] = folder.name;
      }
    }

    return notesAsync.when(
      loading: () => const LoadingSkeleton(),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Error: $error\n\nStack: $stack',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 14),
          ),
        ),
      ),
      data: (notes) {
        if (notes.isEmpty) {
          return const EmptyState();
        }

        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: notes.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final note = notes[index];
            // Look up folder name: if note has folderId, get folder name; otherwise "All notes"
            final folderName = note.folderId != null
                ? (folderMap[note.folderId] ??
                      AppStrings.tr(ref, AppStrings.allNotes))
                : AppStrings.tr(ref, AppStrings.allNotes);

            return Dismissible(
              key: Key(note.id),
              direction: DismissDirection.endToStart,
              onDismissed: (direction) {
                ref.read(notesRepositoryProvider).deleteNote(note.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${note.title} deleted')),
                );
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
                openColor: Theme.of(
                  context,
                ).scaffoldBackgroundColor, // Was hardcoded to 1F2123
                transitionDuration: const Duration(milliseconds: 500),
                closedBuilder: (context, action) {
                  return NoteCard(
                    note: note,
                    index: index,
                    onTap: action,
                    folderName: folderName,
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
    );
  }

  Widget _buildFoldersView() {
    final foldersAsync = ref.watch(foldersStreamProvider);
    final folderCountsAsync = ref.watch(folderNoteCountsProvider);
    final allNotesCountAsync = ref.watch(allNotesCountProvider);

    return foldersAsync.when(
      loading: () => const LoadingSkeleton(),
      error: (error, stack) => Center(child: Text('Error: $error')),
      data: (folders) {
        final counts = folderCountsAsync.valueOrNull ?? {};
        final allNotesCount = allNotesCountAsync.valueOrNull ?? 0;

        if (folders.isEmpty) {
          return Column(
            children: [
              // All Notes card always shown
              AllNotesCard(
                noteCount: allNotesCount,
                onTap: () {
                  // Navigate to all notes (could filter to uncategorized)
                },
                index: 0,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: EmptyState(
                  icon: Icons.folder_outlined,
                  title: AppStrings.tr(ref, AppStrings.noFoldersYet),
                  subtitle: AppStrings.tr(ref, AppStrings.tapToCreateFolder),
                ),
              ),
            ],
          );
        }

        return ListView.builder(
          itemCount: folders.length + 1, // +1 for All Notes
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AllNotesCard(
                  noteCount: allNotesCount,
                  onTap: () {
                    // Show all uncategorized notes
                  },
                  index: 0,
                ),
              );
            }

            final folder = folders[index - 1];
            final noteCount = counts[folder.id] ?? 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FolderCard(
                folder: folder,
                noteCount: noteCount,
                index: index,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FolderDetailPage(folder: folder),
                    ),
                  );
                },
                onLongPress: () {
                  _showFolderOptions(folder);
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showFolderOptions(Folder folder) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
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
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.edit,
                color: Theme.of(context).iconTheme.color,
              ),
              title: Text(
                AppStrings.tr(ref, AppStrings.rename),
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Show rename dialog
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: Text(
                AppStrings.tr(ref, AppStrings.delete),
                style: GoogleFonts.inter(color: Colors.redAccent),
              ),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await _confirmDeleteFolder(folder);
                if (confirm == true) {
                  await ref
                      .read(notesRepositoryProvider)
                      .deleteFolder(folder.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmDeleteFolder(Folder folder) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        title: Text(
          AppStrings.tr(
            ref,
            AppStrings.confirmDeleteFolder,
          ).replaceAll('%s', folder.name),
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          AppStrings.tr(ref, AppStrings.notesMovedToAll),
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
              AppStrings.tr(ref, AppStrings.delete),
              style: GoogleFonts.inter(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderItem({required String title, required String count}) {
    return _FloatingWrapper(
      child: Container(
        width: double.infinity,
        height: 85,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E), // TODO: check usages usage
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            // Yellow Folder Icon
            SvgPicture.string(
              '''<svg width="45" height="45" viewBox="0 0 45 45" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M7.5 37.5C6.46875 37.5 5.58625 37.1331 4.8525 36.3994C4.11875 35.6656 3.75125 34.7825 3.75 33.75V11.25C3.75 10.2188 4.1175 9.33625 4.8525 8.6025C5.5875 7.86875 6.47 7.50125 7.5 7.5H18.75L22.5 11.25H37.5C38.5312 11.25 39.4144 11.6175 40.1494 12.3525C40.8844 13.0875 41.2513 13.97 41.25 15V33.75C41.25 34.7812 40.8831 35.6644 40.1494 36.3994C39.4156 37.1344 38.5325 37.5012 37.5 37.5H7.5Z" fill="#E8B731" />
</svg>''',
              width: 40,
              height: 40,
            ),
            const SizedBox(width: 16),
            // Text Column
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    count,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: const Color(0xFF8C8C8C),
                    ),
                  ),
                ],
              ),
            ),
            // Chevron
            const Icon(Icons.chevron_right, color: Color(0xFF8C8C8C), size: 20),
          ],
        ),
      ),
    );
  }
}

/// Floating wrapper with hover/tap animations for any widget
class _FloatingWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _FloatingWrapper({required this.child, this.onTap});

  @override
  State<_FloatingWrapper> createState() => _FloatingWrapperState();
}

class _FloatingWrapperState extends State<_FloatingWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double hoverScale = _isHovered ? 1.04 : 1.0;
    final double hoverLift = _isHovered ? -2.0 : 0.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: GestureDetector(
        onTapDown: widget.onTap != null ? (_) => _controller.forward() : null,
        onTapUp: widget.onTap != null ? (_) => _controller.reverse() : null,
        onTapCancel: widget.onTap != null ? () => _controller.reverse() : null,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double combinedScale = hoverScale * _scaleAnimation.value;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              transform: Matrix4.identity()
                ..translate(0.0, hoverLift)
                ..scale(combinedScale),
              transformAlignment: Alignment.center,
              child: widget.child,
            );
          },
        ),
      ),
    );
  }
}
