import 'dart:convert';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/models/page.dart';

class PdfService {
  pw.Font? _regularFont;
  pw.Font? _boldFont;

  /// Load fonts that support Turkish characters
  Future<void> _loadFonts() async {
    if (_regularFont != null && _boldFont != null) return;

    _regularFont = await PdfGoogleFonts.notoSansRegular();
    _boldFont = await PdfGoogleFonts.notoSansBold();
  }

  /// Generate PDF from all pages in a book
  Future<File> generatePdfFromBook(
    String bookTitle,
    List<NotePage> pages, {
    bool Function()? isCancelled,
  }) async {
    await _loadFonts();
    if (isCancelled != null && isCancelled()) {
      throw Exception('Cancelled');
    }
    final pdf = pw.Document();

    final footerStyle = pw.TextStyle(font: _regularFont, fontSize: 10, color: PdfColors.grey500);

    // Content pages: book title (small, centered) → SECTION TITLE (bold) → separator → notes
    final bookTitleStyle = pw.TextStyle(font: _regularFont, fontSize: 11, color: PdfColors.grey600);
    final sectionTitleStyle = pw.TextStyle(font: _boldFont, fontSize: 20);

    for (final page in pages) {
      if (isCancelled != null && isCancelled()) {
        throw Exception('Cancelled');
      }
      if (page.isAdvanced && page.drawingJson != null) {
        try {
          final decoded = jsonDecode(page.drawingJson!);
          if (decoded is Map && decoded.containsKey('pages')) {
            final List<dynamic> subPages = decoded['pages'];
            for (var i = 0; i < subPages.length; i++) {
              if (isCancelled != null && isCancelled()) {
                throw Exception('Cancelled');
              }
              final subPage = subPages[i];
              final text = subPage['text'] as String? ?? '';
              final base64Img = subPage['imageData'] as String?;
              
              pdf.addPage(
                pw.Page(
                  pageFormat: PdfPageFormat.a4,
                  margin: const pw.EdgeInsets.all(40),
                  build: (pw.Context context) {
                    return pw.Stack(
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            // Book title — centered, small
                            pw.Center(
                              child: pw.Text(bookTitle, style: bookTitleStyle),
                            ),
                            pw.SizedBox(height: 8),
                            // Section title — bold, centered (only on first sub-page)
                            if (i == 0) ...[
                              pw.Center(
                                child: pw.Text(page.title, style: sectionTitleStyle),
                              ),
                              pw.SizedBox(height: 6),
                              pw.Divider(thickness: 1, color: PdfColors.grey400),
                              pw.SizedBox(height: 10),
                            ],
                            if (text.isNotEmpty)
                              pw.Paragraph(
                                text: text,
                                style: pw.TextStyle(font: _regularFont, fontSize: 12, lineSpacing: 6),
                              ),
                          ],
                        ),
                        // Image overlays
                        ..._buildPdfImageOverlays(subPage),
                        // Text box overlays
                        ..._buildPdfTextBoxOverlays(subPage),
                        if (base64Img != null && base64Img.isNotEmpty)
                          pw.Positioned.fill(
                            child: pw.Image(
                              pw.MemoryImage(base64Decode(base64Img)),
                              fit: pw.BoxFit.contain,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              );
            }
          }
        } catch (e) {
          print("PDF Export Error: $e");
        }
      } else {
        // Standard single page export
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(40),
            header: (pw.Context context) {
              return pw.Column(
                children: [
                  // Book title — centered, small
                  pw.Center(
                    child: pw.Text(bookTitle, style: bookTitleStyle),
                  ),
                  pw.SizedBox(height: 6),
                  // Section title — bold, centered
                  pw.Center(
                    child: pw.Text(page.title, style: sectionTitleStyle),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Divider(thickness: 1, color: PdfColors.grey400),
                  pw.SizedBox(height: 8),
                ],
              );
            },
            footer: (pw.Context context) {
              return pw.Container(
                alignment: pw.Alignment.centerRight,
                margin: const pw.EdgeInsets.only(top: 10),
                child: pw.Text('Sayfa ${context.pageNumber}', style: footerStyle),
              );
            },
            build: (pw.Context context) {
              final contentWidgets = <pw.Widget>[
                if (page.content.isNotEmpty)
                  pw.Paragraph(
                    text: page.content,
                    style: pw.TextStyle(font: _regularFont, fontSize: 12, lineSpacing: 6),
                  ),
              ];

              if (page.drawingImagePath != null) {
                final file = File(page.drawingImagePath!);
                if (file.existsSync()) {
                  final image = pw.MemoryImage(file.readAsBytesSync());
                  contentWidgets.add(pw.SizedBox(height: 20));
                  contentWidgets.add(pw.Center(child: pw.Image(image)));
                }
              }

              return contentWidgets;
            },
          ),
        );
      }
    }

    final sanitizedTitle = bookTitle.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    return _savePdf(pdf, sanitizedTitle);
  }

  /// Generate PDF from selected pages
  Future<File> generatePdfFromSelectedPages(
    String bookTitle,
    List<NotePage> selectedPages, {
    bool Function()? isCancelled,
  }) async {
    return generatePdfFromBook(bookTitle, selectedPages, isCancelled: isCancelled);
  }

  Future<File> _savePdf(pw.Document pdf, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${dir.path}/pdfs');
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }

    final file = File('${pdfDir.path}/$fileName.pdf');
    final bytes = await pdf.save();
    await file.writeAsBytes(bytes);
    return file;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  /// Build positioned image overlays for PDF from sub-page JSON
  List<pw.Widget> _buildPdfImageOverlays(Map<String, dynamic> subPage) {
    final overlays = subPage['imageOverlays'] as List<dynamic>?;
    if (overlays == null || overlays.isEmpty) return [];

    // Scale factor: approximate screen to A4 (515 x 730 usable area at 40 margin)
    const pdfW = 515.0;
    const pdfH = 730.0;
    const screenW = 360.0;
    const screenH = 600.0;
    const sx = pdfW / screenW;
    const sy = pdfH / screenH;

    return overlays.map<pw.Widget>((o) {
      final pos = o['position'] as Map<String, dynamic>?;
      final sz = o['size'] as Map<String, dynamic>?;
      final b64 = o['base64Data'] as String?;
      if (b64 == null || b64.isEmpty) return pw.SizedBox();
      final dx = (pos?['dx'] as num?)?.toDouble() ?? 0;
      final dy = (pos?['dy'] as num?)?.toDouble() ?? 0;
      final w = (sz?['w'] as num?)?.toDouble() ?? 200;
      final h = (sz?['h'] as num?)?.toDouble() ?? 150;
      return pw.Positioned(
        left: dx * sx,
        top: dy * sy,
        child: pw.Image(
          pw.MemoryImage(base64Decode(b64)),
          width: w * sx,
          height: h * sy,
          fit: pw.BoxFit.cover,
        ),
      );
    }).toList();
  }

  /// Build positioned text box overlays for PDF from sub-page JSON
  List<pw.Widget> _buildPdfTextBoxOverlays(Map<String, dynamic> subPage) {
    final overlays = subPage['textBoxOverlays'] as List<dynamic>?;
    if (overlays == null || overlays.isEmpty) return [];

    const pdfW = 515.0;
    const pdfH = 730.0;
    const screenW = 360.0;
    const screenH = 600.0;
    const sx = pdfW / screenW;
    const sy = pdfH / screenH;

    return overlays.map<pw.Widget>((o) {
      final pos = o['position'] as Map<String, dynamic>?;
      final sz = o['size'] as Map<String, dynamic>?;
      final text = o['text'] as String? ?? '';
      if (text.isEmpty) return pw.SizedBox();
      final dx = (pos?['dx'] as num?)?.toDouble() ?? 0;
      final dy = (pos?['dy'] as num?)?.toDouble() ?? 0;
      final w = (sz?['w'] as num?)?.toDouble() ?? 200;
      final h = (sz?['h'] as num?)?.toDouble() ?? 100;
      final fontSize = (o['fontSize'] as num?)?.toDouble() ?? 16;
      final isBold = o['isBold'] as bool? ?? false;

      return pw.Positioned(
        left: dx * sx,
        top: dy * sy,
        child: pw.Container(
          width: w * sx,
          height: h * sy,
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              font: isBold ? _boldFont : _regularFont,
              fontSize: fontSize * 0.75, // scale for PDF
            ),
          ),
        ),
      );
    }).toList();
  }
}
