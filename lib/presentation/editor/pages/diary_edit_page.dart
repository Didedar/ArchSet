import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:io';
import '../../../core/di/app_scope.dart';
import '../../../core/localization/app_strings.dart';
import '../../../data/database/app_database.dart';
import '../../audio/bloc/audio_bloc.dart';
import '../../locale/bloc/locale_bloc.dart';
import '../../transcription/bloc/transcription_bloc.dart';
import '../../widgets/audio_player_widget.dart';
import '../../pages/transcription_page.dart';
import '../../pages/drawing_page.dart';
import 'package:flutter_quill/quill_delta.dart';

import '../../ai_chat/ai_chat_page.dart';
import 'package:image_picker/image_picker.dart';
import '../../widgets/arch_image_embed.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:drift/drift.dart' as drift;
import '../bloc/editor_bloc.dart';

class DiaryEditPage extends StatefulWidget {
  final String? noteId;
  final String? initialTitle;
  final String? initialContent;
  final String? initialFolderId;
  final String? initialAudioPath;

  const DiaryEditPage({
    super.key,
    this.noteId,
    this.initialTitle,
    this.initialContent,
    this.initialFolderId,
    this.initialAudioPath,
  });

  @override
  State<DiaryEditPage> createState() => _DiaryEditPageState();
}

class _DiaryEditPageState extends State<DiaryEditPage> {
  late QuillController _quillController;
  late TextEditingController _titleController;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  String? _folderId;
  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _editorScrollController = ScrollController();

  /// Style at the current selection, refreshed by [_onSelectionChanged].
  ///
  /// Drives the format toolbar's active states. Caching it here means the
  /// toolbar costs one document walk per selection change instead of one per
  /// button per build, and — because it is a notifier — a selection change
  /// rebuilds only the toolbar rather than the whole editor page.
  final ValueNotifier<Style> _selectionStyle = ValueNotifier(const Style());

  @override
  void initState() {
    super.initState();
    _initQuillController();
    _quillController.addListener(_onSelectionChanged);
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _folderId = widget.initialFolderId;

    // Reset audio state first, then load this diary's audio if present
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final audioBloc = context.read<AudioBloc>();
      // Clear any previous diary's audio state
      audioBloc.add(const AudioReset());
      // Load audio for this diary if it has recordings
      if (widget.initialAudioPath != null) {
        audioBloc.add(AudioInitRequested(widget.initialAudioPath));
      }
    });
  }

  void _initQuillController() {
    if (widget.initialContent != null && widget.initialContent!.isNotEmpty) {
      try {
        // Try to parse as JSON (Quill Delta format)
        final jsonContent = jsonDecode(widget.initialContent!);
        _quillController = QuillController(
          document: Document.fromJson(jsonContent),
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (e) {
        // If not valid JSON, treat as plain text
        _quillController = QuillController(
          document: Document()..insert(0, widget.initialContent!),
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    } else {
      _quillController = QuillController.basic();
    }
  }

  @override
  void dispose() {
    // Only save if we are not deleting (handled in delete method)
    // But actually, we might want to autosave on back.
    // Ideally check if deleted. But for now, save is simpler.
    // If note was deleted, _saveNote might re-create it if we are not careful.
    // We'll leave the explicit save on back button for now, but dispose shouldn't trigger save async logic blindly.
    // _saveNote(); // Removed from dispose to avoid async issues or resurrecting deleted notes.
    _quillController.removeListener(_onSelectionChanged);
    _quillController.dispose();
    _titleController.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    _selectionStyle.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onSelectionChanged() {
    _selectionStyle.value = _quillController.getSelectionStyle();
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    // Save Quill document as JSON string
    final contentJson = jsonEncode(
      _quillController.document.toDelta().toJson(),
    );
    final plainText = _quillController.document.toPlainText().trim();

    final noteId = widget.noteId ?? const Uuid().v4();
    final editorBloc = context.read<EditorBloc>();
    editorBloc.add(
      EditorSaveRequested(
        noteId: noteId,
        title: title,
        contentJson: contentJson,
        plainText: plainText,
        folderId: _folderId,
        audioPath: context.read<AudioBloc>().state.audioPath,
      ),
    );
    await editorBloc.stream.firstWhere((s) => s is EditorSaveSuccess);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _toggleRecording() {
    context.read<AudioBloc>().add(
      AudioRecordingToggleRequested(
        engine: context.read<TranscriptionBloc>().state.engine,
        languageCode: context.read<LocaleBloc>().state.locale.languageCode,
      ),
    );
  }

  void _showLinkDialog() {
    final linkController = TextEditingController();
    final theme = Theme.of(context);
    final locale = context.read<LocaleBloc>().state.locale;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        title: Text(
          AppStrings.tr(locale, AppStrings.insertLink),
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        content: TextField(
          controller: linkController,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: AppStrings.tr(locale, AppStrings.enterLinkUrl),
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFFF9000)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppStrings.tr(locale, AppStrings.cancel),
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final link = linkController.text.trim();
              if (link.isNotEmpty) {
                _quillController.formatSelection(LinkAttribute(link));
              }
              Navigator.pop(context);
            },
            child: Text(
              AppStrings.tr(locale, AppStrings.insert),
              style: const TextStyle(color: Color(0xFFFF9000)),
            ),
          ),
        ],
      ),
    );
  }

  /// Performs AI rewriting of the current document text
  Future<void> _performAIRewrite() async {
    final plainText = _quillController.document.toPlainText().trim();
    final theme = Theme.of(context);
    final locale = context.read<LocaleBloc>().state.locale;

    if (plainText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.tr(locale, AppStrings.noTextToRewrite)),
          backgroundColor: theme.brightness == Brightness.dark
              ? const Color(0xFF2C2C2E)
              : Colors.grey[800],
        ),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF9000)),
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.tr(locale, AppStrings.rewriteLoading),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );

    final editorBloc = context.read<EditorBloc>();
    editorBloc.add(EditorAiRewriteRequested(plainText));
    final result = await editorBloc.stream.firstWhere(
      (s) => s is EditorAiRewriteSuccess || s is EditorAiRewriteFailure,
    );

    if (mounted) Navigator.of(context).pop();

    switch (result) {
      case EditorAiRewriteSuccess(:final text):
        if (mounted) {
          _showAiRewriteResultDialog(text, theme);
        }
      case EditorAiRewriteFailure(:final exceptionMessage):
        if (mounted) {
          final message = exceptionMessage != null
              ? 'Error: $exceptionMessage'
              : AppStrings.tr(locale, AppStrings.rewriteFail);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: theme.brightness == Brightness.dark
                  ? const Color(0xFF2C2C2E)
                  : Colors.grey[800],
            ),
          );
        }
      default:
        break;
    }
  }

  void _showAiRewriteResultDialog(String rewrittenText, ThemeData theme) {
    final locale = context.read<LocaleBloc>().state.locale;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        title: Text(
          AppStrings.tr(locale, AppStrings.aiRewriteResult),
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: Text(
              rewrittenText,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                height: 1.5,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              AppStrings.tr(locale, AppStrings.cancel),
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              // Replace document content with rewritten text (parsed)
              final delta = _parseMarkdownToDelta(rewrittenText);
              _quillController.document = Document.fromDelta(delta);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppStrings.tr(locale, AppStrings.rewriteSuccess),
                  ),
                  backgroundColor: theme.brightness == Brightness.dark
                      ? const Color(0xFF2C2C2E)
                      : Colors.grey[800],
                ),
              );
            },
            child: Text(
              AppStrings.tr(locale, AppStrings.apply),
              style: const TextStyle(color: Color(0xFFFF9000)),
            ),
          ),
        ],
      ),
    );
  }

  /// Simple parser to convert basic Markdown to Quill Delta
  Delta _parseMarkdownToDelta(String markdown) {
    final delta = Delta();
    final lines = markdown.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Headers
      if (line.startsWith('# ')) {
        delta.insert(line.substring(2) + '\n', {'header': 1});
        continue;
      }
      if (line.startsWith('## ')) {
        delta.insert(line.substring(3) + '\n', {'header': 2});
        continue;
      }
      if (line.startsWith('### ')) {
        delta.insert(line.substring(4) + '\n', {'header': 3});
        continue;
      }

      // Bullet points
      if (line.trim().startsWith('- ') || line.trim().startsWith('* ')) {
        delta.insert(line.trim().substring(2) + '\n', {'list': 'bullet'});
        continue;
      }

      // Numbered lists
      if (RegExp(r'^\d+\. ').hasMatch(line.trim())) {
        final match = RegExp(r'^\d+\. ').firstMatch(line.trim());
        if (match != null) {
          delta.insert(line.trim().substring(match.end) + '\n', {
            'list': 'ordered',
          });
          continue;
        }
      }

      // Blockquotes
      if (line.startsWith('> ')) {
        delta.insert(line.substring(2) + '\n', {'blockquote': true});
        continue;
      }

      // Bold/Italic processing
      _parseInlineStyles(delta, line);

      // Add newline if not the last line
      if (i < lines.length - 1) {
        delta.insert('\n');
      }
    }

    // Ensure it ends with a newline
    if (delta.last.data is String &&
        !(delta.last.data as String).endsWith('\n')) {
      delta.insert('\n');
    }

    return delta;
  }

  void _parseInlineStyles(Delta delta, String text) {
    // Very basic inline style parser - assumes non-nested for simplicity
    // Handles **bold** and *italic*
    final boldRegex = RegExp(r'\*\*(.*?)\*\*');

    int currentIndex = 0;

    // We can use a more robust approach but regex splitting is easiest for simple cases
    // Improve later if needed. For now, let's just insert plain text to avoid breaking.
    // Or we can try to find matches and insert them with attributes.

    // Let's implement a simple scanner
    final matches = boldRegex.allMatches(text);
    if (matches.isEmpty) {
      delta.insert(text);
      return;
    }

    for (final match in matches) {
      if (match.start > currentIndex) {
        delta.insert(text.substring(currentIndex, match.start));
      }
      delta.insert(match.group(1)!, {'bold': true});
      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      delta.insert(text.substring(currentIndex));
    }
  }

  void _showCustomMenu() {
    if (_overlayEntry != null) {
      _removeOverlay();
      return;
    }

    final theme = Theme.of(context);
    final locale = context.read<LocaleBloc>().state.locale;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Semi-transparent barrier to close menu on tap outside
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeOverlay,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            width: 192,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(-160, 40), // Adjust offset to align properly
              child: _AnimatedMenu(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 192,
                    // Removed fixed height to allow content to fit
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          offset: const Offset(0, 4),
                          blurRadius: 4,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 10),
                        _buildMenuItem(
                          Icons.picture_as_pdf_outlined,
                          AppStrings.tr(locale, AppStrings.pdf),
                          onTap: () => _generatePdf(),
                        ),
                        _buildMenuItem(
                          Icons.chat_bubble_outline,
                          AppStrings.tr(locale, AppStrings.aiChat),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AIChatPage(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 5),
                        // Separator
                        Container(
                          width: 175,
                          height: 2,
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.dark
                                ? const Color(0xFFF7F7F7).withOpacity(0.1)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        const SizedBox(height: 5),
                        _buildMenuItem(
                          Icons.image_outlined,
                          AppStrings.tr(locale, AppStrings.image),
                          onTap: () => _pickImage(ImageSource.gallery),
                        ),
                        _buildMenuItem(
                          Icons.camera_alt_outlined,
                          AppStrings.tr(locale, AppStrings.camera),
                          onTap: () => _pickImage(ImageSource.camera),
                        ),
                        _buildMenuItem(
                          Icons.crop_free,
                          AppStrings.tr(locale, AppStrings.scan),
                          onTap: () => _scanImage(),
                        ),
                        _buildMenuItem(
                          Icons.palette_outlined,
                          AppStrings.tr(locale, AppStrings.drawing),
                          onTap: () async {
                            final imagePath = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DrawingPage(),
                              ),
                            );

                            if (imagePath != null && imagePath is String) {
                              int index = _quillController.selection.baseOffset;
                              int length =
                                  _quillController.selection.extentOffset -
                                  index;

                              if (index < 0) {
                                index =
                                    _quillController.document.length -
                                    1; // Insert at end if no selection
                                length = 0;
                              }

                              _quillController.replaceText(
                                index,
                                length,
                                BlockEmbed.image(imagePath),
                                null,
                              );
                              // Move cursor after the image
                              _quillController.moveCursorToPosition(index + 1);
                              // Add a newline after image to continue typing easily
                              _quillController.document.insert(index + 1, '\n');
                            }
                          },
                        ),
                        _buildMenuItem(
                          Icons.description_outlined,
                          AppStrings.tr(locale, AppStrings.transcription),
                          onTap: () {
                            _navigateToTranscriptionPage();
                          },
                        ),
                        _buildMenuItem(
                          Icons.auto_fix_high_outlined,
                          AppStrings.tr(locale, AppStrings.aiRewrite),
                          onTap: () {
                            _performAIRewrite();
                          },
                        ),
                        _buildMenuItem(
                          Icons.mic_none_outlined,
                          AppStrings.tr(locale, AppStrings.audioRecording),
                          onTap: _toggleRecording,
                        ),
                        const SizedBox(height: 5),
                        // Separator
                        Container(
                          width: 175,
                          height: 2,
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.dark
                                ? const Color(0xFFF7F7F7).withOpacity(0.1)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        const SizedBox(height: 5),
                        _buildDeleteMenuItem(),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildMenuItem(IconData icon, String text, {VoidCallback? onTap}) {
    return _HoverMenuItem(
      onTap: () {
        _removeOverlay();
        onTap?.call();
      },
      icon: icon,
      text: text,
    );
  }

  Widget _buildDeleteMenuItem() {
    final locale = context.read<LocaleBloc>().state.locale;
    return _HoverMenuItem(
      onTap: () async {
        _removeOverlay();
        final confirm = await _confirmDelete();
        if (confirm == true) {
          await _deleteNote();
        }
      },
      icon: Icons.delete_outline,
      text: AppStrings.tr(locale, AppStrings.delete),
      isDestructive: true,
    );
  }

  Future<bool?> _confirmDelete() {
    final theme = Theme.of(context);
    final locale = context.read<LocaleBloc>().state.locale;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        title: Text(
          AppStrings.tr(locale, AppStrings.deleteDiaryConfirmTitle),
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        content: Text(
          AppStrings.tr(locale, AppStrings.deleteDiaryConfirmMessage),
          style: TextStyle(
            fontFamily: 'Inter',
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppStrings.tr(locale, AppStrings.cancel),
              style: TextStyle(
                fontFamily: 'Inter',
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppStrings.tr(locale, AppStrings.delete),
              style: const TextStyle(
                fontFamily: 'Inter',
                color: Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNote() async {
    if (widget.noteId == null) return;
    final noteId = widget.noteId!;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final editorBloc = context.read<EditorBloc>();
    editorBloc.add(EditorDeleteRequested(noteId));
    await editorBloc.stream.firstWhere((s) => s is EditorDeleteSuccess);

    if (!mounted) return;
    Navigator.of(context).pop(); // Close loading
    Navigator.of(context).pop(); // Close the editor page
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      final imagePath = pickedFile.path;

      // Get location if permission granted
      double? latitude;
      double? longitude;
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final position = await Geolocator.getCurrentPosition(
            timeLimit: const Duration(seconds: 5),
          );
          latitude = position.latitude;
          longitude = position.longitude;
        }
      } catch (e) {
        debugPrint('Location error: $e');
      }

      // Save metadata to DB
      try {
        final db = context.di.core.database;
        final id = const Uuid().v4();
        await db
            .into(db.imageMetadata)
            .insert(
              ImageMetadataCompanion(
                id: drift.Value(id),
                imagePath: drift.Value(imagePath),
                latitude: drift.Value(latitude),
                longitude: drift.Value(longitude),
                capturedAt: drift.Value(DateTime.now()),
              ),
            );
      } catch (e) {
        debugPrint('Metadata DB Save error: $e');
      }

      int index = _quillController.selection.baseOffset;
      int length = _quillController.selection.extentOffset - index;

      if (index < 0) {
        index =
            _quillController.document.length -
            1; // Insert at end if no selection
        length = 0;
      }

      _quillController.replaceText(
        index,
        length,
        BlockEmbed.image(imagePath),
        null,
      );
      // Move cursor after the image
      _quillController.moveCursorToPosition(index + 1);
      // Add a newline after image to continue typing easily
      _quillController.document.insert(index + 1, '\n');
    }
  }

  Future<void> _scanImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile == null) return;

    final theme = Theme.of(context);
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF9000)),
            ),
            const SizedBox(height: 16),
            Text(
              "Scanning...",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );

    final editorBloc = context.read<EditorBloc>();
    editorBloc.add(EditorImageScanRequested(pickedFile.path));
    final result = await editorBloc.stream.firstWhere(
      (s) => s is EditorScanSuccess || s is EditorScanFailure,
    );

    if (mounted) Navigator.of(context).pop(); // Close loading

    switch (result) {
      case EditorScanSuccess(:final text):
        int index = _quillController.selection.baseOffset;
        if (index < 0) {
          index = _quillController.document.length - 1;
        }
        _quillController.document.insert(index, text);
        _quillController.document.insert(index + text.length, '\n');
        _quillController.moveCursorToPosition(index + text.length + 1);
      case EditorScanFailure(:final message):
        if (message != null && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      default:
        break;
    }
  }

  Future<void> _generatePdf() async {
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fontItalic = await PdfGoogleFonts.robotoItalic();
    final fontBoldItalic = await PdfGoogleFonts.robotoBoldItalic();

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
        italic: fontItalic,
        boldItalic: fontBoldItalic,
      ),
    );
    final title = _titleController.text.trim();
    final delta = _quillController.document.toDelta();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          final List<pw.Widget> children = [];

          // Title
          if (title.isNotEmpty) {
            children.add(
              pw.Header(
                level: 0,
                child: pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            );
            children.add(pw.SizedBox(height: 10));
          }

          // Content
          for (final op in delta.toList()) {
            if (op.data is String) {
              final text = op.data as String;
              if (text.trim().isEmpty) continue;

              // Basic style mapping (simplified)
              pw.TextStyle style = const pw.TextStyle(fontSize: 12);
              if (op.attributes != null) {
                if (op.attributes!['bold'] == true) {
                  style = style.copyWith(fontWeight: pw.FontWeight.bold);
                }
                if (op.attributes!['italic'] == true) {
                  style = style.copyWith(fontStyle: pw.FontStyle.italic);
                }
                if (op.attributes!['header'] == 1) {
                  style = style.copyWith(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  );
                }
              }
              children.add(pw.Text(text, style: style));
            } else if (op.data is Map &&
                (op.data as Map).containsKey('image')) {
              final imagePath = (op.data as Map)['image'] as String;
              try {
                final image = pw.MemoryImage(File(imagePath).readAsBytesSync());
                children.add(pw.SizedBox(height: 10));
                children.add(
                  pw.Center(
                    child: pw.Image(image, fit: pw.BoxFit.contain, height: 300),
                  ),
                );
                children.add(pw.SizedBox(height: 10));
              } catch (e) {
                debugPrint('PDF Image error: $e');
              }
            }
          }

          return children;
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }

  void _navigateToTranscriptionPage() {
    final audioState = context.read<AudioBloc>().state;
    final theme = Theme.of(context);
    final locale = context.read<LocaleBloc>().state.locale;

    // Get transcription text from the Quill document
    final transcriptionText = _quillController.document.toPlainText().trim();

    // Get real audio segments
    final audioSegments = audioState.segments;
    final audioDuration = audioState.playbackTotalDuration;

    // Get audio file paths from segments
    final audioPaths = audioSegments.map((s) => s.filePath).toList();

    // Get audio name from first segment if available
    String audioName = 'Audio - 001';
    if (audioSegments.isNotEmpty) {
      audioName = audioSegments.first.name;
    }

    if (transcriptionText.isEmpty && audioPaths.isEmpty) {
      // Show snackbar if there's no transcription
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.tr(locale, AppStrings.noTranscription)),
          backgroundColor: theme.brightness == Brightness.dark
              ? const Color(0xFF2C2C2E)
              : Colors.grey[800],
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TranscriptionPage(
          audioPaths: audioPaths.isNotEmpty ? audioPaths : null,
          audioSegments: audioSegments.isNotEmpty ? audioSegments : null,
          transcriptionText: transcriptionText.isNotEmpty
              ? transcriptionText
              : null,
          audioDuration: audioDuration,
          audioName: audioName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = context.watch<LocaleBloc>().state.locale;

    return BlocListener<AudioBloc, AudioState>(
      listenWhen: (previous, current) =>
          current.lastTranscription != null &&
          current.lastTranscription != previous.lastTranscription,
      listener: (context, state) {
        final text = state.lastTranscription!;
        if (text.trim().isNotEmpty) {
          // Insert transcription at the end of the document
          final length = _quillController.document.length;
          final currentText = _quillController.document.toPlainText().trim();
          if (currentText.isEmpty) {
            _quillController.document.insert(0, text);
          } else {
            _quillController.document.insert(length - 1, '\n\n$text');
          }
        }
        context.read<AudioBloc>().add(const AudioLastTranscriptionCleared());
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.chevron_left,
                              color: theme.iconTheme.color,
                              size: 28,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () async {
                              await _saveNote();
                              if (mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: TextField(
                              controller: _titleController,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                fontSize: 24,
                                color: theme.colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                hintText: AppStrings.tr(
                                  locale,
                                  AppStrings.diary,
                                ),
                                hintStyle: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 24,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Icons Row. Scoped to the audio fields it actually reads
                    // so recording/playback ticks can't rebuild the page.
                    BlocBuilder<AudioBloc, AudioState>(
                      buildWhen: (p, c) =>
                          p.isRecording != c.isRecording ||
                          p.recordingDuration != c.recordingDuration ||
                          p.hasRecording != c.hasRecording,
                      builder: (context, audioState) => Row(
                        children: [
                          // Recording Indicator
                          if (audioState.isRecording)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C2C2E),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDuration(
                                      audioState.recordingDuration,
                                    ),
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else ...[
                            // Audio Player Widget if audio exists and NOT recording
                            if (audioState.hasRecording)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: IconButton(
                                  icon: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.graphic_eq,
                                      color: theme.colorScheme.onSurface,
                                      size: 20,
                                    ),
                                  ),
                                  onPressed: () {
                                    context.read<AudioBloc>().add(
                                      const AudioPlayerExpansionToggled(),
                                    );
                                  },
                                ),
                              ),

                            CompositedTransformTarget(
                              link: _layerLink,
                              child: IconButton(
                                icon: SvgPicture.string(
                                  '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"> <path d="M12 13C12.5523 13 13 12.5523 13 12C13 11.4477 12.5523 11 12 11C11.4477 11 11 11.4477 11 12C11 12.5523 11.4477 13 12 13Z" stroke="${isDark ? 'white' : 'black'}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" /> <path d="M19 13C19.5523 13 20 12.5523 20 12C20 11.4477 19.5523 11 19 11C18.4477 11 18 11.4477 18 12C18 12.5523 18.4477 13 19 13Z" stroke="${isDark ? 'white' : 'black'}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" /> <path d="M5 13C5.55228 13 6 12.5523 6 12C6 11.4477 5.55228 11 5 11C4.44772 11 4 11.4477 4 12C4 12.5523 4.44772 13 5 13Z" stroke="${isDark ? 'white' : 'black'}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" /> </svg>''',
                                ),
                                onPressed: _showCustomMenu,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Audio Player (Visible when expanded)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: AudioPlayerWidget(),
              ),

              Divider(
                color: theme.colorScheme.onSurface.withOpacity(0.1),
                height: 1,
              ),

              // Editor
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: QuillEditor(
                    controller: _quillController,
                    focusNode: _editorFocusNode,
                    scrollController: _editorScrollController,
                    config: QuillEditorConfig(
                      scrollable: true,
                      autoFocus: false,
                      expands: false,
                      padding: EdgeInsets.zero,
                      embedBuilders: [ArchImageEmbedBuilder()],
                    ),
                  ),
                ),
              ),

              // Bottom Toolbar
              Container(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: 8, // Little padding before safe area/bottom
                ),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF1C1C1E)
                      : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Formatting Buttons Row. Listens to the cached
                    // selection style so only this row rebuilds on a
                    // selection change.
                    ValueListenableBuilder<Style>(
                      valueListenable: _selectionStyle,
                      builder: (context, style, _) => SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFormatButton(
                              label: 'H',
                              onTap: () => _toggleAttribute(Attribute.header),
                              isActive: _isActiveIn(style, Attribute.header),
                            ),
                            const SizedBox(width: 8),
                            _buildFormatButton(
                              icon: Icons.undo,
                              onTap: () => _quillController.undo(),
                            ),
                            const SizedBox(width: 8),
                            _buildFormatButton(
                              icon: Icons.redo,
                              onTap: () => _quillController.redo(),
                            ),
                            const SizedBox(width: 8),
                            _buildFormatButton(
                              label: 'B',
                              isBold: true,
                              onTap: () => _toggleAttribute(Attribute.bold),
                              isActive: _isActiveIn(style, Attribute.bold),
                            ),
                            const SizedBox(width: 8),
                            _buildFormatButton(
                              label: 'U',
                              isUnderline: true,
                              onTap: () =>
                                  _toggleAttribute(Attribute.underline),
                              isActive: _isActiveIn(style, Attribute.underline),
                            ),
                            const SizedBox(width: 8),
                            _buildFormatButton(
                              icon: Icons.format_strikethrough,
                              onTap: () =>
                                  _toggleAttribute(Attribute.strikeThrough),
                              isActive: _isActiveIn(
                                style,
                                Attribute.strikeThrough,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildFormatButton(
                              icon: Icons.check_box_outlined,
                              onTap: () =>
                                  _toggleAttribute(Attribute.unchecked),
                              isActive:
                                  _isActiveIn(style, Attribute.unchecked) ||
                                  _isActiveIn(style, Attribute.checked),
                            ),
                            const SizedBox(width: 8),
                            _buildFormatButton(
                              icon: Icons.format_list_bulleted,
                              onTap: () => _toggleAttribute(Attribute.ul),
                              isActive: _isActiveIn(style, Attribute.ul),
                            ),
                            const SizedBox(width: 8),
                            _buildFormatButton(
                              icon: Icons.format_list_numbered,
                              onTap: () => _toggleAttribute(Attribute.ol),
                              isActive: _isActiveIn(style, Attribute.ol),
                            ),
                            const SizedBox(width: 8),
                            _buildFormatButton(
                              icon: Icons.code,
                              onTap: () =>
                                  _toggleAttribute(Attribute.codeBlock),
                              isActive: _isActiveIn(style, Attribute.codeBlock),
                            ),
                            const SizedBox(width: 8),
                            _buildFormatButton(
                              icon: Icons.format_quote,
                              onTap: () =>
                                  _toggleAttribute(Attribute.blockQuote),
                              isActive: _isActiveIn(
                                style,
                                Attribute.blockQuote,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildFormatButton(
                              icon: Icons.link,
                              onTap: _showLinkDialog,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Action Buttons Row (Audio & AI)
                    Row(
                      children: [
                        Expanded(
                          // Only the record button's own colour depends on
                          // audio state, so it subscribes to that one flag.
                          child: BlocSelector<AudioBloc, AudioState, bool>(
                            selector: (state) => state.isRecording,
                            builder: (context, isRecording) =>
                                _buildAudioButton(isRecording, isDark, locale),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: _buildAiButton(isDark, locale)),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isActiveIn(Style style, Attribute attribute) {
    return style.containsKey(attribute.key) &&
        style.attributes[attribute.key]!.value == attribute.value;
  }

  void _toggleAttribute(Attribute attribute) {
    final isToggled = _isActiveIn(
      _quillController.getSelectionStyle(),
      attribute,
    );
    if (isToggled) {
      _quillController.formatSelection(Attribute.clone(attribute, null));
    } else {
      _quillController.formatSelection(attribute);
    }
  }

  Widget _buildFormatButton({
    String? label,
    IconData? icon,
    VoidCallback? onTap,
    bool isActive = false,
    bool isBold = false,
    bool isUnderline = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.onSurface
              : (isDark ? const Color(0xFF2C2C2E) : Colors.grey[200]),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(
                icon,
                size: 20,
                color: isActive
                    ? theme.colorScheme.surface
                    : theme.colorScheme.onSurface.withOpacity(0.7),
              )
            : Text(
                label ?? '',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
                  fontSize: 16,
                  decoration: isUnderline ? TextDecoration.underline : null,
                  color: isActive
                      ? theme.colorScheme.surface
                      : theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
      ),
    );
  }

  Widget _buildAudioButton(bool isRecording, bool isDark, Locale locale) {
    return InkWell(
      onTap: _toggleRecording,
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          color: isRecording
              ? const Color(0xFFFF9F0A) // Orange/Yellow when recording
              : (isDark ? const Color(0xFF2C2C2E) : Colors.grey[200]),
          borderRadius: BorderRadius.circular(30),
          border: isRecording
              ? Border.all(color: Colors.white.withOpacity(0.2), width: 1)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isRecording) ...[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ] else
              Icon(
                Icons.mic, // Or a waveform icon
                color: isDark ? Colors.white : Colors.black,
                size: 20,
              ),
            if (!isRecording) const SizedBox(width: 8),
            Text(
              isRecording
                  ? AppStrings.tr(
                      locale,
                      AppStrings.audioRecording,
                    ) // or just "Recording"
                  : AppStrings.tr(locale, AppStrings.audioRecording).replaceAll(
                      'Recording',
                      'Audio',
                    ), // Hacky fallback if string encompasses both
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                color: isRecording
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black),
              ),
            ),
            if (isRecording) ...[
              const SizedBox(width: 8),
              // Red dot indicator
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black.withOpacity(0.2)),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAiButton(bool isDark, Locale locale) {
    return InkWell(
      onTap: () {
        _performAIRewrite();
      },
      borderRadius: BorderRadius.circular(30),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_fix_high, // Changed to reflect "Rewrite/Fix"
              color: isDark ? Colors.white : Colors.black,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              AppStrings.tr(locale, AppStrings.aiAssistant), // "AI Assistant"
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _AnimatedMenu extends StatefulWidget {
  final Widget child;

  const _AnimatedMenu({required this.child});

  @override
  State<_AnimatedMenu> createState() => _AnimatedMenuState();
}

class _AnimatedMenuState extends State<_AnimatedMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      alignment: Alignment.topRight,
      child: FadeTransition(opacity: _fadeAnimation, child: widget.child),
    );
  }
}

class _HoverMenuItem extends StatefulWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String text;
  final bool isDestructive;

  const _HoverMenuItem({
    required this.onTap,
    required this.icon,
    required this.text,
    this.isDestructive = false,
  });

  @override
  State<_HoverMenuItem> createState() => _HoverMenuItemState();
}

class _HoverMenuItemState extends State<_HoverMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.isDestructive
        ? Colors.redAccent
        : theme.colorScheme.onSurface;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: _isHovered
              ? theme.colorScheme.onSurface.withOpacity(0.05)
              : Colors.transparent,
          child: Row(
            children: [
              Icon(widget.icon, color: color, size: 20),
              const SizedBox(width: 12),
              Text(
                widget.text,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
