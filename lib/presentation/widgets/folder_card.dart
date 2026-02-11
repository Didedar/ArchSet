import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/database/app_database.dart';

/// Animated folder card widget with hover/tap effects
class FolderCard extends StatefulWidget {
  final Folder folder;
  final int noteCount;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final int index;

  const FolderCard({
    super.key,
    required this.folder,
    required this.noteCount,
    required this.onTap,
    this.onLongPress,
    this.index = 0,
  });

  @override
  State<FolderCard> createState() => _FolderCardState();
}

class _FolderCardState extends State<FolderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 300 + (widget.index * 50)),
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
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _folderColor {
    try {
      return Color(int.parse(widget.folder.color.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFFE8B731);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double hoverScale = _isHovered ? 1.04 : 1.0;
    final double hoverLift = _isHovered ? -3.0 : 0.0;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onTap();
              },
              onLongPress: widget.onLongPress,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                transform: Matrix4.identity()
                  ..translate(0.0, hoverLift)
                  ..scale(hoverScale),
                transformAlignment: Alignment.center,
                child: Container(
                  width: double.infinity,
                  height: 85,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _isHovered
                        ? [
                            BoxShadow(
                              color: _folderColor.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Folder Icon
                      Hero(
                        tag: 'folder-${widget.folder.id}',
                        child: SvgPicture.string(
                          _getFolderSvg(_folderColor),
                          width: 45,
                          height: 45,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Text Column
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.folder.name,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${widget.noteCount} ${widget.noteCount == 1 ? 'note' : 'notes'}',
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
                      const Icon(
                        Icons.chevron_right,
                        color: Color(0xFF8C8C8C),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getFolderSvg(Color color) {
    final colorHex =
        '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
    return '''<svg width="45" height="45" viewBox="0 0 45 45" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M7.5 37.5C6.46875 37.5 5.58625 37.1331 4.8525 36.3994C4.11875 35.6656 3.75125 34.7825 3.75 33.75V11.25C3.75 10.2188 4.1175 9.33625 4.8525 8.6025C5.5875 7.86875 6.47 7.50125 7.5 7.5H18.75L22.5 11.25H37.5C38.5312 11.25 39.4144 11.6175 40.1494 12.3525C40.8844 13.0875 41.2513 13.97 41.25 15V33.75C41.25 34.7812 40.8831 35.6644 40.1494 36.3994C39.4156 37.1344 38.5325 37.5012 37.5 37.5H7.5Z" fill="$colorHex" />
</svg>''';
  }
}

/// "All Notes" card (special folder for uncategorized notes)
class AllNotesCard extends StatefulWidget {
  final int noteCount;
  final VoidCallback onTap;
  final int index;

  const AllNotesCard({
    super.key,
    required this.noteCount,
    required this.onTap,
    this.index = 0,
  });

  @override
  State<AllNotesCard> createState() => _AllNotesCardState();
}

class _AllNotesCardState extends State<AllNotesCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isHovered = false;

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
      begin: const Offset(0, 0.2),
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
    final double hoverScale = _isHovered ? 1.04 : 1.0;
    final double hoverLift = _isHovered ? -3.0 : 0.0;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onTap();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              transform: Matrix4.identity()
                ..translate(0.0, hoverLift)
                ..scale(hoverScale),
              transformAlignment: Alignment.center,
              child: Container(
                width: double.infinity,
                height: 85,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(16),
                  border: _isHovered
                      ? Border.all(
                          color: const Color(0xFFFF9000).withValues(alpha: 0.5),
                          width: 1,
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    // Notes Icon
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9000),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.note_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Text Column
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'All Notes',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${widget.noteCount} ${widget.noteCount == 1 ? 'note' : 'notes'}',
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
                    const Icon(
                      Icons.chevron_right,
                      color: Color(0xFF8C8C8C),
                      size: 20,
                    ),
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
