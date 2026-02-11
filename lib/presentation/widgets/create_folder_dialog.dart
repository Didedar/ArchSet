import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../core/localization/app_strings.dart';
import '../../data/database/app_database.dart';
import '../providers/notes_provider.dart';

/// Animated dialog for creating a new folder
class CreateFolderDialog extends ConsumerStatefulWidget {
  const CreateFolderDialog({super.key});

  @override
  ConsumerState<CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends ConsumerState<CreateFolderDialog>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  String _selectedColor = '#E8B731'; // Default yellow
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  static const List<String> _colors = [
    '#E8B731', // Yellow
    '#6B4EFF', // Purple
    '#4ECDC4', // Teal
    '#FF6B6B', // Red
    '#4CAF50', // Green
    '#2196F3', // Blue
    '#FF9800', // Orange
    '#9C27B0', // Deep Purple
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _createFolder() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final folder = Folder(
      id: const Uuid().v4(),
      name: name,
      color: _selectedColor,
      createdAt: DateTime.now(),
      isDeleted: false,
    );

    await ref.read(notesRepositoryProvider).createFolder(folder);
    HapticFeedback.mediumImpact();

    if (mounted) {
      Navigator.of(context).pop(folder);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final textColor = theme.colorScheme.onSurface;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Dialog(
              backgroundColor: cardColor, // Using theme card color
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.tr(ref, AppStrings.createNewFolder),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Folder name input
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: theme
                            .scaffoldBackgroundColor, // Darker/Lighter background for input
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _nameController,
                        autofocus: true,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: textColor,
                        ),
                        cursorColor: theme.colorScheme.primary,
                        decoration: InputDecoration(
                          hintText: AppStrings.tr(ref, AppStrings.folderName),
                          hintStyle: GoogleFonts.inter(
                            fontSize: 16,
                            color: textColor.withOpacity(0.5),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Color picker
                    Text(
                      AppStrings.tr(ref, AppStrings.colorLabel),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _colors.map((color) {
                        final isSelected = color == _selectedColor;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedColor = color);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Color(
                                int.parse(color.replaceFirst('#', '0xFF')),
                              ),
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: textColor, width: 3)
                                  : null,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Color(
                                          int.parse(
                                            color.replaceFirst('#', '0xFF'),
                                          ),
                                        ).withOpacity(0.5),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: _DialogButton(
                            label: AppStrings.tr(ref, AppStrings.cancel),
                            onTap: () => Navigator.of(context).pop(),
                            isOutlined: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DialogButton(
                            label: AppStrings.tr(ref, AppStrings.create),
                            onTap: _createFolder,
                            color: Color(
                              int.parse(
                                _selectedColor.replaceFirst('#', '0xFF'),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DialogButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isOutlined;
  final Color? color;

  const _DialogButton({
    required this.label,
    required this.onTap,
    this.isOutlined = false,
    this.color,
  });

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: widget.isOutlined
                    ? Colors.transparent
                    : (widget.color ??
                          theme.colorScheme.surfaceContainerHighest),
                borderRadius: BorderRadius.circular(12),
                border: widget.isOutlined
                    ? Border.all(
                        color: theme.colorScheme.onSurface.withOpacity(0.2),
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: widget.isOutlined
                      ? theme.colorScheme.onSurface
                      : Colors
                            .white, // Button with color background usually has white text
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Show the create folder dialog
Future<Folder?> showCreateFolderDialog(BuildContext context) {
  return showGeneralDialog<Folder>(
    context: context,
    barrierDismissible: true,
    barrierLabel:
        'Create Folder', // Accessibility label, no need to localize strictly but good to have
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const CreateFolderDialog();
    },
  );
}
