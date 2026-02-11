import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/localization/app_strings.dart';

class DrawingPage extends ConsumerStatefulWidget {
  const DrawingPage({super.key});

  @override
  ConsumerState<DrawingPage> createState() => _DrawingPageState();
}

class _DrawingPageState extends ConsumerState<DrawingPage> {
  // State for drawing
  List<DrawingPoint?> points = [];
  Color selectedColor = Colors.white;
  double strokeWidth = 3.0;
  List<DrawingPoint?> undoHistory = [];

  // For Undo/Redo - simplified: we can just store snapshots of points list
  // Ideally we store actions. For now, let's just store the full list in history stack
  List<List<DrawingPoint?>> history = [];
  int historyIndex = -1;
  final GlobalKey _canvasKey = GlobalKey();

  void _saveToHistory() {
    // If we undo and then draw, remove the "future" history
    if (historyIndex < history.length - 1) {
      history.removeRange(historyIndex + 1, history.length);
    }
    // Store a copy of the current points
    history.add(List.from(points));
    historyIndex++;
  }

  void _undo() {
    if (historyIndex > 0) {
      historyIndex--;
      setState(() {
        points = List.from(history[historyIndex]);
      });
    } else if (historyIndex == 0) {
      historyIndex = -1;
      setState(() {
        points = [];
      });
    }
  }

  void _redo() {
    if (historyIndex < history.length - 1) {
      historyIndex++;
      setState(() {
        points = List.from(history[historyIndex]);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Color Palette
            _buildColorPalette(),

            // Canvas Area
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onPanStart: (details) {
                      setState(() {
                        points.add(
                          DrawingPoint(
                            point: details.localPosition,
                            paint: Paint()
                              ..color = selectedColor
                              ..strokeCap = StrokeCap.round
                              ..isAntiAlias = true
                              ..strokeWidth = strokeWidth,
                          ),
                        );
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        points.add(
                          DrawingPoint(
                            point: details.localPosition,
                            paint: Paint()
                              ..color = selectedColor
                              ..strokeCap = StrokeCap.round
                              ..isAntiAlias = true
                              ..strokeWidth = strokeWidth,
                          ),
                        );
                      });
                    },
                    onPanEnd: (details) {
                      setState(() {
                        // Add null to separate lines
                        points.add(null);
                        _saveToHistory();
                      });
                    },
                    child: RepaintBoundary(
                      key: _canvasKey,
                      child: CustomPaint(
                        painter: DrawingPainter(points: points),
                        size: Size.infinite,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom Toolbar
            _buildBottomToolbar(),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPalette() {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;

    final List<Color> colors = [
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.white,
      Colors.brown,
      Colors.redAccent,
      Colors.lightBlue,
      Colors.blue,
      Colors.purple,
      Colors.black,
      Colors.grey,
      const Color(0xFF3E3E40),
      const Color(0xFF5E5E60),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 14,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1,
        ),
        itemBuilder: (context, index) {
          final color = colors[index];
          final isSelected = selectedColor == color;
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedColor = color;
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: theme.colorScheme.onSurface, width: 2)
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomToolbar() {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final iconColor = theme.colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      margin: const EdgeInsets.only(bottom: 10, left: 16, right: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Eraser
          IconButton(
            icon: Icon(
              Icons.cleaning_services_outlined,
              color: selectedColor == theme.scaffoldBackgroundColor
                  ? theme.colorScheme.primary
                  : iconColor.withOpacity(0.5),
            ),
            onPressed: () {
              setState(() {
                // Eraser just paints with background color for now
                selectedColor = theme.scaffoldBackgroundColor;
              });
            },
          ),
          const SizedBox(width: 16),
          // Undo
          IconButton(
            icon: Icon(Icons.undo, color: iconColor),
            onPressed: _undo,
          ),
          const SizedBox(width: 16),
          // Redo
          IconButton(
            icon: Icon(Icons.redo, color: iconColor),
            onPressed: _redo,
          ),
          const SizedBox(width: 20),
          // Done Button
          GestureDetector(
            onTap: _saveAndExit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary, // Use primary color
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                AppStrings.tr(ref, AppStrings.done),
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndExit() async {
    try {
      final RenderBox? renderBox =
          _canvasKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      final size = renderBox.size;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, size.width, size.height),
      );

      // We don't paint background so it mimics transparency or paper

      final painter = DrawingPainter(points: points);
      painter.paint(canvas, size);

      final picture = recorder.endRecording();
      final img = await picture.toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'drawing_${const Uuid().v4()}.png';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(buffer);

      if (mounted) {
        Navigator.pop(context, file.path);
      }
    } catch (e) {
      debugPrint('Error saving drawing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppStrings.tr(ref, AppStrings.errorSavingDrawing)}: $e',
            ),
          ),
        );
      }
    }
  }
}

class DrawingPoint {
  Offset point;
  Paint paint;

  DrawingPoint({required this.point, required this.paint});
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPoint?> points;

  DrawingPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(
          points[i]!.point,
          points[i + 1]!.point,
          points[i]!.paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
