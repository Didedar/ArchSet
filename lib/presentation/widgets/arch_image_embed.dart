import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../../core/di/app_scope.dart';
import '../../data/database/app_database.dart';
import '../../data/services/api_service.dart';
import '../../data/services/backend_gemini_service.dart';
import 'package:drift/drift.dart' as drift;

class ArchImageEmbedBuilder extends EmbedBuilder {
  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final imageUrl = embedContext.node.value.data;
    return ArchImageEmbed(imagePath: imageUrl);
  }
}

class ArchImageEmbed extends StatefulWidget {
  final String imagePath;

  const ArchImageEmbed({super.key, required this.imagePath});

  @override
  State<ArchImageEmbed> createState() => _ArchImageEmbedState();
}

class _ArchImageEmbedState extends State<ArchImageEmbed> {
  bool _isLoading = false;

  Future<void> _analyzeImage() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final db = context.di.core.database;
      // Check for existing metadata
      final existing =
          await (db.select(db.imageMetadata)
                ..where((tbl) => tbl.imagePath.equals(widget.imagePath)))
              .getSingleOrNull();

      if (existing != null && existing.analysisResult != null) {
        final data = Map<String, dynamic>.from(
          jsonDecode(existing.analysisResult!),
        );
        data['latitude'] = existing.latitude;
        data['longitude'] = existing.longitude;
        if (mounted) {
          _showAnalysisDialog(data, existing.id);
        }
      } else {
        // Not found locally, call backend
        final geminiService = BackendGeminiService(
          apiService: ApiService(authService: context.di.auth.repository),
        );

        // Pass location if available locally (even if analysis is missing)
        final jsonString = await geminiService.analyzeImage(
          widget.imagePath,
          latitude: existing?.latitude,
          longitude: existing?.longitude,
        );

        if (jsonString != null) {
          // Save to DB
          if (existing != null) {
            await (db.update(
              db.imageMetadata,
            )..where((t) => t.id.equals(existing.id))).write(
              ImageMetadataCompanion(analysisResult: drift.Value(jsonString)),
            );
          } else {
            // Should not happen if _pickImage saves it, but just in case
            // If we don't have an ID, we can't easily insert without creating a new logical entry.
            // For now, assume it might not exist if added before this feature.
            // We won't insert a new row here without ID optimization, but let's try to ignore saving if no row exists
            // OR generate a new ID if we really want to persist.
            // Let's safe fail to non-persistence if no initial row.
          }

          final data = Map<String, dynamic>.from(jsonDecode(jsonString));
          data['latitude'] = existing?.latitude;
          data['longitude'] = existing?.longitude;
          if (mounted) {
            _showAnalysisDialog(data, existing?.id);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to analyze image. Please try again.'),
                backgroundColor: Color(0xFF2C2C2E),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFF2C2C2E),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showAnalysisDialog(Map<String, dynamic> data, String? metadataId) {
    final db = context.di.core.database;
    showDialog(
      context: context,
      builder: (context) => _AnalysisDialog(
        data: data,
        metadataId: metadataId,
        onDelete: () async {
          if (metadataId != null) {
            await (db.update(
              db.imageMetadata,
            )..where((t) => t.id.equals(metadataId))).write(
              const ImageMetadataCompanion(analysisResult: drift.Value(null)),
            );
          }
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  /// Target decode width for the inline thumbnail, in physical pixels.
  int _inlineCacheWidth(BuildContext context) {
    final media = MediaQuery.of(context);
    return (media.size.width * media.devicePixelRatio).round();
  }

  /// Target decode width for the full-screen viewer. Allows 2x the screen
  /// width so a pinch-zoom still resolves detail.
  int _fullScreenCacheWidth(BuildContext context) {
    final media = MediaQuery.of(context);
    return (media.size.width * media.devicePixelRatio * 2).round();
  }

  @override
  Widget build(BuildContext context) {
    // 50 padding from left and right as per design (approx)
    // Actually standard Quill padding is fine, but we might want to center it.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(widget.imagePath),
              fit: BoxFit.cover,
              // Decode at display size, not at capture size. A 12MP photo
              // costs ~48MB as decoded RGBA; a few of them in one entry blow
              // the image cache and force repeated decode/evict churn. The
              // cache key includes cacheWidth, so this is also what lets the
              // inline and full-screen views hold separate, right-sized
              // copies instead of two full-resolution ones.
              cacheWidth: _inlineCacheWidth(context),
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  color: Colors.grey[800],
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.white),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Positioned.fill(
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF9000)),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _analyzeImage,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        backgroundColor: Colors.transparent,
                        insetPadding: EdgeInsets.zero,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: InteractiveViewer(
                                minScale: 0.5,
                                maxScale: 4.0,
                                child: Image.file(
                                  File(widget.imagePath),
                                  fit: BoxFit.contain,
                                  // Capped at screen width so zooming stays
                                  // sharp without decoding the full original.
                                  cacheWidth: _fullScreenCacheWidth(context),
                                  gaplessPlayback: true,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 40,
                              right: 20,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 30,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: const Icon(
                      Icons.fullscreen, // Or remove_red_eye
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisDialog extends StatelessWidget {
  final Map<String, dynamic> data;
  final String? metadataId;
  final VoidCallback? onDelete;

  const _AnalysisDialog({required this.data, this.metadataId, this.onDelete});

  Widget _buildLocationSection(double? lat, double? long) {
    if (lat == null || long == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location Context',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.location_on, color: Color(0xFFFF9000), size: 16),
            const SizedBox(width: 8),
            Text(
              '${lat.toStringAsFixed(5)}, ${long.toStringAsFixed(5)}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSection(String title, Map<String, dynamic>? content) {
    if (content == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 8),
        ...content.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatKey(entry.key)}: ',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    fontFamily: 'Inter',
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.value?.toString() ?? 'unknown',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _formatKey(String key) {
    // Convert snake_case to Title Case
    return key
        .split('_')
        .map((word) {
          if (word.isEmpty) return '';
          return '${word[0].toUpperCase()}${word.substring(1)}';
        })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent, // Glassmorphism effect base
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E).withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24, width: 0.5),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Geo-data information',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onDelete != null)
                      IconButton(
                        onPressed: onDelete,
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        tooltip: 'Delete Analysis',
                      ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(color: Colors.white24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLocationSection(
                      data['latitude'] as double?,
                      data['longitude'] as double?,
                    ),
                    _buildSection('Spatial Context', data['spatial_context']),
                    _buildSection(
                      'Physical Characteristics',
                      data['physical_characteristics'],
                    ),
                    _buildSection(
                      'Relational Context',
                      data['relational_context'],
                    ),
                    _buildSection(
                      'Administrative Data',
                      data['administrative_data'],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
