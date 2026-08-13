import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Helper function to open the custom Image Cropper Dialog
Future<File?> showImageCropper(BuildContext context, {required File imageFile}) async {
  return await showGeneralDialog<File?>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Görsel Kırpma',
    pageBuilder: (ctx, anim1, anim2) {
      return ImageCropperDialog(imageFile: imageFile);
    },
  );
}

class ImageCropperDialog extends StatefulWidget {
  final File imageFile;

  const ImageCropperDialog({super.key, required this.imageFile});

  @override
  State<ImageCropperDialog> createState() => _ImageCropperDialogState();
}

class _ImageCropperDialogState extends State<ImageCropperDialog> {
  ui.Image? _decodedImage;
  bool _isLoading = true;
  int _rotationQuarterTurns = 0;

  // Normalized crop rectangle relative to rendered image box [0..1]
  Rect _normalizedCrop = const Rect.fromLTWH(0.05, 0.05, 0.90, 0.90);

  // Active handle during drag gesture
  _HandleType? _activeHandle;
  Offset? _dragStartOffset;
  Rect? _dragStartCrop;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    setState(() => _isLoading = true);
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _decodedImage = frame.image;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading image for cropper: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _rotateClockwise() {
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
  }

  void _resetCrop() {
    setState(() {
      _normalizedCrop = const Rect.fromLTWH(0.02, 0.02, 0.96, 0.96);
      _rotationQuarterTurns = 0;
    });
  }

  Future<ui.Image> _getRotatedImage(ui.Image src, int turns) async {
    turns = turns % 4;
    if (turns == 0) return src;

    final int w = (turns % 2 == 1) ? src.height : src.width;
    final int h = (turns % 2 == 1) ? src.width : src.height;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));

    if (turns == 1) {
      canvas.translate(w.toDouble(), 0);
      canvas.rotate(math.pi / 2);
    } else if (turns == 2) {
      canvas.translate(w.toDouble(), h.toDouble());
      canvas.rotate(math.pi);
    } else if (turns == 3) {
      canvas.translate(0, h.toDouble());
      canvas.rotate(3 * math.pi / 2);
    }

    canvas.drawImage(src, Offset.zero, Paint()..filterQuality = ui.FilterQuality.high);
    final picture = recorder.endRecording();
    return await picture.toImage(w, h);
  }

  Future<void> _saveCroppedImage() async {
    if (_decodedImage == null) return;

    setState(() => _isLoading = true);

    try {
      final rotated = await _getRotatedImage(_decodedImage!, _rotationQuarterTurns);

      final double relLeft = _normalizedCrop.left.clamp(0.0, 1.0);
      final double relTop = _normalizedCrop.top.clamp(0.0, 1.0);
      final double relWidth = _normalizedCrop.width.clamp(0.05, 1.0 - relLeft);
      final double relHeight = _normalizedCrop.height.clamp(0.05, 1.0 - relTop);

      final int srcX = (relLeft * rotated.width).round().clamp(0, rotated.width - 1);
      final int srcY = (relTop * rotated.height).round().clamp(0, rotated.height - 1);
      final int srcW = (relWidth * rotated.width).round().clamp(1, rotated.width - srcX);
      final int srcH = (relHeight * rotated.height).round().clamp(1, rotated.height - srcY);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, srcW.toDouble(), srcH.toDouble()));

      canvas.drawImageRect(
        rotated,
        Rect.fromLTWH(srcX.toDouble(), srcY.toDouble(), srcW.toDouble(), srcH.toDouble()),
        Rect.fromLTWH(0, 0, srcW.toDouble(), srcH.toDouble()),
        Paint()..filterQuality = ui.FilterQuality.high,
      );

      final croppedUiImage = await recorder.endRecording().toImage(srcW, srcH);
      final byteData = await croppedUiImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        if (mounted) Navigator.pop(context, null);
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final timeStamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/cropped_note_$timeStamp.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      if (mounted) {
        Navigator.pop(context, file);
      }
    } catch (e) {
      debugPrint('Error cropping image: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context, null),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Görseli Kırp ve Düzenle',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'Köşe ve kenarlardan tutarak kırpma alanını ayarlayın',
              style: TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_right_rounded, color: Color(0xFF38BDF8), size: 24),
            tooltip: '90° Sağa Döndür',
            onPressed: _isLoading ? null : _rotateClockwise,
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded, color: Colors.amber, size: 24),
            tooltip: 'Kırpmayı Sıfırla',
            onPressed: _isLoading ? null : _resetCrop,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading || _decodedImage == null
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF14B8A6)),
                  SizedBox(height: 12),
                  Text('Görsel işleniyor...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final turns = _rotationQuarterTurns % 4;
                        final imgW = (turns % 2 == 1) ? _decodedImage!.height : _decodedImage!.width;
                        final imgH = (turns % 2 == 1) ? _decodedImage!.width : _decodedImage!.height;

                        final containerAspect = constraints.maxWidth / constraints.maxHeight;
                        final imgAspect = imgW / imgH;

                        double renderW, renderH;
                        if (imgAspect > containerAspect) {
                          renderW = constraints.maxWidth;
                          renderH = constraints.maxWidth / imgAspect;
                        } else {
                          renderH = constraints.maxHeight;
                          renderW = constraints.maxHeight * imgAspect;
                        }

                        final offsetX = (constraints.maxWidth - renderW) / 2;
                        final offsetY = (constraints.maxHeight - renderH) / 2;
                        final imageRect = Rect.fromLTWH(offsetX, offsetY, renderW, renderH);

                        final cropLeft = imageRect.left + _normalizedCrop.left * renderW;
                        final cropTop = imageRect.top + _normalizedCrop.top * renderH;
                        final cropWidth = _normalizedCrop.width * renderW;
                        final cropHeight = _normalizedCrop.height * renderH;
                        final cropRect = Rect.fromLTWH(cropLeft, cropTop, cropWidth, cropHeight);

                        return Stack(
                          children: [
                            // 1. Rendered Rotated Image
                            Positioned.fromRect(
                              rect: imageRect,
                              child: RotatedBox(
                                quarterTurns: _rotationQuarterTurns,
                                child: Image.file(
                                  widget.imageFile,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ),

                            // 2. Dark Overlay Outside Crop Rect
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _CropMaskPainter(cropRect: cropRect, imageRect: imageRect),
                              ),
                            ),

                            // 3. Crop Box Border & Touch Gesture Area
                            Positioned.fromRect(
                              rect: cropRect,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFF14B8A6), width: 2.2),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black26, blurRadius: 4),
                                  ],
                                ),
                              ),
                            ),

                            // 4. Interactive Drag Handles (Center & 8 Knobs)
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onPanStart: (details) {
                                  final pos = details.localPosition;
                                  _activeHandle = _detectHandle(pos, cropRect);
                                  _dragStartOffset = pos;
                                  _dragStartCrop = _normalizedCrop;
                                },
                                onPanUpdate: (details) {
                                  if (_activeHandle == null || _dragStartOffset == null || _dragStartCrop == null) return;
                                  final delta = details.localPosition - _dragStartOffset!;
                                  final normDx = delta.dx / renderW;
                                  final normDy = delta.dy / renderH;

                                  setState(() {
                                    _normalizedCrop = _updateNormalizedCrop(
                                      _dragStartCrop!,
                                      _activeHandle!,
                                      normDx,
                                      normDy,
                                    );
                                  });
                                },
                                onPanEnd: (_) {
                                  _activeHandle = null;
                                  _dragStartOffset = null;
                                  _dragStartCrop = null;
                                },
                                child: Stack(
                                  children: [
                                    // Corner Handle Knobs
                                    _buildHandleKnob(cropRect.topLeft, _HandleType.topLeft),
                                    _buildHandleKnob(cropRect.topRight, _HandleType.topRight),
                                    _buildHandleKnob(cropRect.bottomLeft, _HandleType.bottomLeft),
                                    _buildHandleKnob(cropRect.bottomRight, _HandleType.bottomRight),

                                    // Edge Center Handles
                                    _buildEdgeKnob(Offset(cropRect.centerLeft.dx, cropRect.centerLeft.dy), true),
                                    _buildEdgeKnob(Offset(cropRect.centerRight.dx, cropRect.centerRight.dy), true),
                                    _buildEdgeKnob(Offset(cropRect.topCenter.dx, cropRect.topCenter.dy), false),
                                    _buildEdgeKnob(Offset(cropRect.bottomCenter.dx, cropRect.bottomCenter.dy), false),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                // Bottom Action Button Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    border: Border(top: BorderSide(color: Colors.white10, width: 1)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text('İptal', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () => Navigator.pop(context, null),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF14B8A6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 4,
                            ),
                            icon: const Icon(Icons.check_circle_rounded, size: 20),
                            label: const Text(
                              'Kırp ve Kaydet',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            onPressed: _saveCroppedImage,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHandleKnob(Offset position, _HandleType type) {
    return Positioned(
      left: position.dx - 14,
      top: position.dy - 14,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF14B8A6), width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildEdgeKnob(Offset position, bool isVertical) {
    return Positioned(
      left: position.dx - (isVertical ? 5 : 16),
      top: position.dy - (isVertical ? 16 : 5),
      child: Container(
        width: isVertical ? 10 : 32,
        height: isVertical ? 32 : 10,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0xFF14B8A6), width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 4),
          ],
        ),
      ),
    );
  }

  _HandleType? _detectHandle(Offset touch, Rect cropRect) {
    const touchRadius = 28.0;

    if ((touch - cropRect.topLeft).distance <= touchRadius) return _HandleType.topLeft;
    if ((touch - cropRect.topRight).distance <= touchRadius) return _HandleType.topRight;
    if ((touch - cropRect.bottomLeft).distance <= touchRadius) return _HandleType.bottomLeft;
    if ((touch - cropRect.bottomRight).distance <= touchRadius) return _HandleType.bottomRight;

    if ((touch - cropRect.topCenter).distance <= touchRadius) return _HandleType.top;
    if ((touch - cropRect.bottomCenter).distance <= touchRadius) return _HandleType.bottom;
    if ((touch - cropRect.centerLeft).distance <= touchRadius) return _HandleType.left;
    if ((touch - cropRect.centerRight).distance <= touchRadius) return _HandleType.right;

    if (cropRect.contains(touch)) return _HandleType.center;

    return null;
  }

  Rect _updateNormalizedCrop(Rect initial, _HandleType handle, double dx, double dy) {
    double left = initial.left;
    double top = initial.top;
    double right = initial.right;
    double bottom = initial.bottom;
    const minSize = 0.08;

    switch (handle) {
      case _HandleType.topLeft:
        left = (initial.left + dx).clamp(0.0, initial.right - minSize);
        top = (initial.top + dy).clamp(0.0, initial.bottom - minSize);
        break;
      case _HandleType.topRight:
        right = (initial.right + dx).clamp(initial.left + minSize, 1.0);
        top = (initial.top + dy).clamp(0.0, initial.bottom - minSize);
        break;
      case _HandleType.bottomLeft:
        left = (initial.left + dx).clamp(0.0, initial.right - minSize);
        bottom = (initial.bottom + dy).clamp(initial.top + minSize, 1.0);
        break;
      case _HandleType.bottomRight:
        right = (initial.right + dx).clamp(initial.left + minSize, 1.0);
        bottom = (initial.bottom + dy).clamp(initial.top + minSize, 1.0);
        break;
      case _HandleType.top:
        top = (initial.top + dy).clamp(0.0, initial.bottom - minSize);
        break;
      case _HandleType.bottom:
        bottom = (initial.bottom + dy).clamp(initial.top + minSize, 1.0);
        break;
      case _HandleType.left:
        left = (initial.left + dx).clamp(0.0, initial.right - minSize);
        break;
      case _HandleType.right:
        right = (initial.right + dx).clamp(initial.left + minSize, 1.0);
        break;
      case _HandleType.center:
        final w = initial.width;
        final h = initial.height;
        left = (initial.left + dx).clamp(0.0, 1.0 - w);
        top = (initial.top + dy).clamp(0.0, 1.0 - h);
        right = left + w;
        bottom = top + h;
        break;
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }
}

enum _HandleType {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  top,
  bottom,
  left,
  right,
  center,
}

class _CropMaskPainter extends CustomPainter {
  final Rect cropRect;
  final Rect imageRect;

  _CropMaskPainter({required this.cropRect, required this.imageRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(imageRect)
      ..addRect(cropRect);
    path.fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CropMaskPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect || oldDelegate.imageRect != imageRect;
  }
}
