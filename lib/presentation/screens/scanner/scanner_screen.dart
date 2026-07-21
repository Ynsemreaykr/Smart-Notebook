import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../data/services/scanner_service.dart';
import '../../../application/providers/book_provider.dart';
import '../../../application/providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/bounce_button.dart';
import '../library/library_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with SingleTickerProviderStateMixin {
  final ScannerService _scannerService = ScannerService();
  File? _capturedFile;
  bool _isProcessing = false;
  int _currentStep = 0; // 0: Viewfinder/Camera, 1: Preview, 2: Crop, 3: Export/Format
  String _selectedFormat = 'PDF'; // PDF, PNG, JPEG
  bool _hasCameraPermission = false;

  // Draggable crop corners
  Offset topLeft = const Offset(40, 50);
  Offset topRight = const Offset(260, 50);
  Offset bottomLeft = const Offset(40, 350);
  Offset bottomRight = const Offset(260, 350);

  late AnimationController _scanAnimCtrl;

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _scanAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanAnimCtrl.dispose();
    super.dispose();
  }

  // Check camera permission
  Future<void> _checkPermission() async {
    final status = await Permission.camera.status;
    setState(() {
      _hasCameraPermission = status.isGranted;
    });
  }

  // Request camera permission
  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      _hasCameraPermission = status.isGranted;
    });
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Belge tarayıcıyı kullanmak için kamera izni vermelisiniz.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // Step 2: Open Camera & Capture photo using service
  Future<void> _capturePhoto() async {
    if (!_hasCameraPermission) {
      await _requestPermission();
      if (!_hasCameraPermission) return;
    }

    setState(() => _isProcessing = true);
    try {
      final file = await _scannerService.captureFromCamera();
      if (file != null) {
        setState(() {
          _capturedFile = file;
          _currentStep = 1; // Proceed to Preview step
        });
      }
    } catch (e) {
      _showError('Kamera Hatası', e.toString());
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // Import image from gallery
  Future<void> _pickFromGallery() async {
    setState(() => _isProcessing = true);
    try {
      final file = await _scannerService.pickFromGallery();
      if (file != null) {
        setState(() {
          _capturedFile = file;
          _currentStep = 1; // Proceed to Preview step
        });
      }
    } catch (e) {
      _showError('Galeri Hatası', e.toString());
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // Export document to Library
  Future<void> _exportDocument() async {
    if (_capturedFile == null) return;
    setState(() => _isProcessing = true);

    try {
      final now = DateTime.now();
      final title = 'Tarama_${now.day}${now.month}_${now.hour}${now.minute}';
      
      if (_selectedFormat == 'PDF') {
        final pdf = pw.Document();
        final imageBytes = await _capturedFile!.readAsBytes();
        final image = pw.MemoryImage(imageBytes);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) {
              return pw.FullPage(
                ignoreMargins: true,
                child: pw.Image(image, fit: pw.BoxFit.cover),
              );
            },
          ),
        );

        final dir = await getTemporaryDirectory();
        final tempPdfFile = File('${dir.path}/$title.pdf');
        await tempPdfFile.writeAsBytes(await pdf.save());

        await context.read<BookProvider>().importPdf(tempPdfFile, title);
      } else {
        await context.read<BookProvider>().importImage(_capturedFile!, title);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Belge başarıyla kütüphanenize aktarıldı!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LibraryScreen()),
        );
      }
    } catch (e) {
      _showError('Dışa Aktarma Hatası', e.toString());
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showError(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  // Feature usage info dialog
  void _showFeatureInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📸 Belge Tarayıcı Hakkında'),
        content: const SingleChildScrollView(
          child: Text(
            'Bu modül fiziksel kağıtlarınızı veya belgelerinizi uygulama içinden tarayıp kütüphanenize aktarmanızı sağlar.\n\n'
            'Adım Adım Tarama Akışı:\n'
            '1. Kamera Vizörü: Hizalama kılavuzlarını kullanarak belgenizi ortalayın.\n'
            '2. Önizleme: Çekilen fotoğrafın kalitesini kontrol edin.\n'
            '3. Kırpma (Crop): Köşeleri kaydırarak tam A4 boyutlarını seçin.\n'
            '4. Format & Export: PDF, PNG veya JPEG olarak kütüphaneye kaydedin.',
            style: TextStyle(height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text(_getStepTitle()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() {
                _currentStep--;
                if (_currentStep == 0) _capturedFile = null;
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Bilgi',
            onPressed: () => _showFeatureInfo(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : _buildCurrentStepWidget(),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Belge Tarayıcı';
      case 1:
        return 'Önizleme';
      case 2:
        return 'Kırpma';
      case 3:
        return 'Dışa Aktar';
      default:
        return 'Belge Tarayıcı';
    }
  }

  Widget _buildCurrentStepWidget() {
    switch (_currentStep) {
      case 0:
        return _buildViewfinder();
      case 1:
        return _buildPreview();
      case 2:
        return _buildCrop();
      case 3:
        return _buildFormatAndExport();
      default:
        return _buildViewfinder();
    }
  }

  // Step 0: Camera Viewfinder with permission handler button
  Widget _buildViewfinder() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.neonBlue.withOpacity(0.3), width: 1.5),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (!_hasCameraPermission)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt_rounded, color: AppTheme.textMuted, size: 64),
                          const SizedBox(height: 16),
                          const Text(
                            'Kamera İzni Gerekli',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tarama yapmak için kamera erişimine izin verin.',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _requestPermission,
                            icon: const Icon(Icons.security_rounded),
                            label: const Text('İzin İste'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.neonBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    // Simulated visual grid overlay
                    Opacity(
                      opacity: 0.08,
                      child: Container(
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('assets/images/grid.png'),
                            repeat: ImageRepeat.repeat,
                          ),
                        ),
                      ),
                    ),

                    // Double rectangle document alignment guide
                    Container(
                      width: 250,
                      height: 350,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.greenAccent.withOpacity(0.8), width: 2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.greenAccent.withOpacity(0.4), width: 1.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),

                    // Interactive scan laser line animation
                    AnimatedBuilder(
                      animation: _scanAnimCtrl,
                      builder: (context, child) {
                        return Positioned(
                          top: 60 + (_scanAnimCtrl.value * 270),
                          child: Container(
                            width: 270,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.greenAccent.withOpacity(0.8),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const Positioned(
                      top: 20,
                      child: Text(
                        'Belgeyi yeşil çerçeve içine ortalayın',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Bottom Controls Bar
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 40),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.photo_library_rounded, size: 28),
                onPressed: _pickFromGallery,
                color: AppTheme.neonAccent,
                tooltip: 'Galeriden Seç',
              ),
              GestureDetector(
                onTap: _capturePhoto,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300, width: 6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 16,
                      )
                    ],
                  ),
                  child: Icon(Icons.camera_alt_rounded, color: AppTheme.darkBg, size: 30),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.flash_off_rounded, size: 28),
                onPressed: () {},
                color: AppTheme.textMuted,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Step 1: Preview Screen
  Widget _buildPreview() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.neonBlue.withOpacity(0.3), width: 1.5),
                image: DecorationImage(
                  image: FileImage(_capturedFile!),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _capturedFile = null;
                      _currentStep = 0;
                    });
                  },
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Tekrar Çek'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: AppTheme.textMuted.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: BounceButton(
                  onTap: () {
                    setState(() {
                      _currentStep = 2; // Go to Crop
                    });
                  },
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.primaryGlow(intensity: 0.4),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Kırpmaya Geç', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Step 2: In-App Crop Screen
  Widget _buildCrop() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          _capturedFile!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    CustomPaint(
                      painter: _CropPainter(
                        topLeft: topLeft,
                        topRight: topRight,
                        bottomLeft: bottomLeft,
                        bottomRight: bottomRight,
                      ),
                      child: Container(),
                    ),
                    _buildCropHandle(topLeft, (newOffset) => setState(() => topLeft = newOffset), constraints),
                    _buildCropHandle(topRight, (newOffset) => setState(() => topRight = newOffset), constraints),
                    _buildCropHandle(bottomLeft, (newOffset) => setState(() => bottomLeft = newOffset), constraints),
                    _buildCropHandle(bottomRight, (newOffset) => setState(() => bottomRight = newOffset), constraints),
                  ],
                );
              },
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _currentStep = 1;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: AppTheme.textMuted.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Geri'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: BounceButton(
                  onTap: () {
                    setState(() {
                      _currentStep = 3; // Go to Export options
                    });
                  },
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.primaryGlow(intensity: 0.4),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Format Seç', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Step 3: Format Select & Export
  Widget _buildFormatAndExport() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.neonBlue.withOpacity(0.15)),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.neonBlue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.description_outlined, color: AppTheme.neonBlue, size: 48),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Taramayı Kütüphaneye Aktar',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Belgenizin kütüphaneye kaydedileceği formatı seçin.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: ['PDF', 'PNG', 'JPEG'].map((fmt) {
                        final active = _selectedFormat == fmt;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: ChoiceChip(
                            label: Text(fmt),
                            selected: active,
                            selectedColor: AppTheme.neonBlue.withOpacity(0.25),
                            backgroundColor: AppTheme.darkCardHigh,
                            labelStyle: TextStyle(
                              color: active ? AppTheme.textPrimary : AppTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (sel) {
                              if (sel) setState(() => _selectedFormat = fmt);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _currentStep = 2;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: AppTheme.textMuted.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Geri'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: BounceButton(
                  onTap: _exportDocument,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.primaryGlow(intensity: 0.5),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Text('KÜTÜPHANEYE KAYDET', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCropHandle(Offset position, Function(Offset) onUpdate, BoxConstraints constraints) {
    return Positioned(
      left: position.dx - 16,
      top: position.dy - 16,
      child: GestureDetector(
        onPanUpdate: (details) {
          final newOffset = Offset(
            (position.dx + details.delta.dx).clamp(0.0, constraints.maxWidth),
            (position.dy + details.delta.dy).clamp(0.0, constraints.maxHeight),
          );
          onUpdate(newOffset);
        },
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.greenAccent,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: const Center(
            child: Icon(Icons.crop_free, size: 14, color: Colors.black),
          ),
        ),
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  final Offset topLeft;
  final Offset topRight;
  final Offset bottomLeft;
  final Offset bottomRight;

  _CropPainter({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final outerPaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final innerPaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..close();

    canvas.drawPath(path, outerPaint);

    final double innerMargin = 12.0;
    final pathInner = Path()
      ..moveTo(topLeft.dx + innerMargin, topLeft.dy + innerMargin)
      ..lineTo(topRight.dx - innerMargin, topRight.dy + innerMargin)
      ..lineTo(bottomRight.dx - innerMargin, bottomRight.dy - innerMargin)
      ..lineTo(bottomLeft.dx + innerMargin, bottomLeft.dy - innerMargin)
      ..close();

    canvas.drawPath(pathInner, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
