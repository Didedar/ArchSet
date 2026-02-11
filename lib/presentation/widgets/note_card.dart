import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/database/app_database.dart';
import '../../core/localization/app_strings.dart';

/// Animated note card with hero transition support
class NoteCard extends ConsumerStatefulWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final int index;
  final String? folderName;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onLongPress,
    required this.index,
    this.folderName,
  });

  @override
  ConsumerState<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends ConsumerState<NoteCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 300 + (widget.index * 50)),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    // We can't really fully translate "5m ago" without arguments in AppStrings.
    // Ideally update AppStrings to support arguments or simple concatenation.
    // For now, I will assume English structure or basic concatenation is acceptable
    // or just use 'ago' from AppStrings.
    // Better: Helper formatted strings.

    final ago = AppStrings.tr(ref, AppStrings.ago);

    if (difference.inMinutes < 1) {
      return AppStrings.tr(ref, AppStrings.justNow);
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m $ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h $ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d $ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  Color _getNoteColor(BuildContext context, int index) {
    // 0: Orange, 1: Neutral, 2: Purple, 3: Red, 4: Teal
    final colors = [
      const Color(0xFFFF9000),
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF2C2C2E)
          : const Color(0xFFF2F2F7), // Light grey for Light mode
      const Color(0xFF6B4EFF),
      const Color(0xFFFF6B6B),
      const Color(0xFF4ECDC4),
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final noteColor = _getNoteColor(context, widget.index);
    final isLightCard = noteColor.computeLuminance() > 0.5;
    final textColor = isLightCard ? Colors.black : Colors.white;
    final secondaryTextColor = isLightCard
        ? Colors.black54
        : const Color(0xFFD9D9D9);
    final badgeColor = isLightCard
        ? Colors.black.withOpacity(0.1)
        : Colors.white.withValues(alpha: 0.25);
    final badgeTextColor = isLightCard ? Colors.black87 : Colors.white;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Hero(
          tag: 'note-${widget.note.id}',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                height: 75,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: noteColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        color: textColor, // Dot matches text color
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.note.title.isEmpty
                                ? AppStrings.tr(ref, AppStrings.untitled)
                                : widget.note.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w500,
                              fontSize: 17,
                              color: textColor,
                            ),
                          ),
                          Text(
                            '${_getRelativeTime(widget.note.date)}${widget.note.audioPath != null ? ' Audio' : ''}',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 80),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.folderName ??
                            AppStrings.tr(ref, AppStrings.allNotes),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          color: badgeTextColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: textColor, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
