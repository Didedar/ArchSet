import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_provider.dart';
import '../../data/models/audio_segment.dart';

/// Audio segments popup widget matching design specifications:
/// - border-radius: 24px
/// - width: 282px
/// - box-shadow: 1px 4px 4px 4px rgba(0, 0, 0, 0.25)
/// - background: #fff
class AudioSegmentsPopup extends ConsumerStatefulWidget {
  final VoidCallback? onClose;

  const AudioSegmentsPopup({super.key, this.onClose});

  @override
  ConsumerState<AudioSegmentsPopup> createState() => _AudioSegmentsPopupState();
}

class _AudioSegmentsPopupState extends ConsumerState<AudioSegmentsPopup> {
  bool _isEditMode = false;
  final Map<int, TextEditingController> _editControllers = {};

  @override
  void dispose() {
    for (final controller in _editControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      if (!_isEditMode) {
        // Save all edits when exiting edit mode
        _saveAllEdits();
      }
    });
  }

  void _saveAllEdits() {
    final audioNotifier = ref.read(audioProvider.notifier);
    for (final entry in _editControllers.entries) {
      audioNotifier.renameSegment(entry.key, entry.value.text);
    }
    _editControllers.clear();
  }

  TextEditingController _getController(int index, String initialValue) {
    if (!_editControllers.containsKey(index)) {
      _editControllers[index] = TextEditingController(text: initialValue);
    }
    return _editControllers[index]!;
  }

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioProvider);
    final audioNotifier = ref.read(audioProvider.notifier);

    if (!audioState.isSegmentsPopupVisible || audioState.segments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 282,
      constraints: const BoxConstraints(minHeight: 127, maxHeight: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.25),
            offset: Offset(1, 4),
            blurRadius: 4,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Record audio',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                GestureDetector(
                  onTap: _toggleEditMode,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit,
                        size: 14,
                        color: _isEditMode ? Colors.blue : Colors.black54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isEditMode ? 'Done' : 'Edit',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: _isEditMode ? Colors.blue : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Segments list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: audioState.segments.length,
              itemBuilder: (context, index) {
                final segment = audioState.segments[index];
                final isActive = index == audioState.activeSegmentIndex;

                return _SegmentListItem(
                  segment: segment,
                  index: index,
                  isActive: isActive,
                  isEditMode: _isEditMode,
                  controller: _isEditMode
                      ? _getController(index, segment.name)
                      : null,
                  onTap: () {
                    audioNotifier.seekToSegment(index);
                    audioNotifier.hideSegmentsPopup();
                    audioNotifier.play();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual segment list item
class _SegmentListItem extends StatelessWidget {
  final AudioSegment segment;
  final int index;
  final bool isActive;
  final bool isEditMode;
  final TextEditingController? controller;
  final VoidCallback onTap;

  const _SegmentListItem({
    required this.segment,
    required this.index,
    required this.isActive,
    required this.isEditMode,
    required this.onTap,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final nameColor = isActive ? const Color(0xFFD02F2F) : Colors.black87;

    return GestureDetector(
      onTap: isEditMode ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // Delete button (only in edit mode)
            if (isEditMode)
              IconButton(
                icon: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.remove, color: Colors.red, size: 14),
                ),
                onPressed: () {
                  // Call delete function
                  final notifier = ProviderScope.containerOf(
                    context,
                  ).read(audioProvider.notifier);
                  notifier.deleteSegment(index);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            if (isEditMode) const SizedBox(width: 8),

            // Name (editable in edit mode)
            Expanded(
              child: isEditMode && controller != null
                  ? TextField(
                      controller: controller,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: nameColor,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Colors.blue),
                        ),
                      ),
                    )
                  : Text(
                      segment.name,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: nameColor,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            // Duration and date
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  segment.formattedDuration,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.black54,
                  ),
                ),
                Text(
                  segment.formattedDate,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: Colors.black38,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
