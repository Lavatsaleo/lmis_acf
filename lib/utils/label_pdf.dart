import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/box_models.dart';

/// PDF label printing utilities.
///
/// This file intentionally contains **no Flutter UI widgets**.
/// It only generates a PDF and sends it to the OS print/share dialog.
class LabelPdf {
  /// Print a single box label (1 label on an A4 page).
  static Future<void> printSingle(BoxItem box) async {
    final doc = pw.Document();
    final format = _a4WithMargin();

    doc.addPage(
      pw.Page(
        pageFormat: format,
        build: (ctx) {
          final w = format.availableWidth;
          final h = format.availableHeight;

          // A comfortable single-label size (still centered on A4).
          final labelW = math.min(w, 90 * PdfPageFormat.mm);
          final labelH = math.min(h, 65 * PdfPageFormat.mm);

          return pw.Center(child: _labelCell(box, labelW, labelH, isSingle: true));
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  /// Print many labels in a grid on A4.
  ///
  /// Default is 3 columns x 8 rows = 24 labels per page.
  static Future<void> printBulk(
    List<BoxItem> boxes, {
    int columns = 3,
    int rows = 8,
  }) async {
    if (boxes.isEmpty) return;

    columns = math.max(1, columns);
    rows = math.max(1, rows);

    final doc = pw.Document();
    final format = _a4WithMargin();

    final labelsPerPage = columns * rows;
    final cellW = format.availableWidth / columns;
    final cellH = format.availableHeight / rows;

    for (int start = 0; start < boxes.length; start += labelsPerPage) {
      final chunk = boxes.skip(start).take(labelsPerPage).toList();

      doc.addPage(
        pw.Page(
          pageFormat: format,
          build: (ctx) {
            return pw.Column(
              children: List.generate(rows, (r) {
                return pw.Row(
                  children: List.generate(columns, (c) {
                    final idx = r * columns + c;
                    if (idx >= chunk.length) {
                      return pw.SizedBox(width: cellW, height: cellH);
                    }
                    return _labelCell(chunk[idx], cellW, cellH);
                  }),
                );
              }),
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  static pw.Widget _labelCell(
    BoxItem box,
    double w,
    double h, {
    bool isSingle = false,
  }) {
    final qrSize = math.min(w, h) * (isSingle ? 0.70 : 0.60);
    final titleSize = isSingle ? 12.0 : 9.0;
    final textSize = isSingle ? 10.0 : 8.0;

    return pw.Container(
      width: w,
      height: h,
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.7),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: box.qrPayload(),
            width: qrSize,
            height: qrSize,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            box.boxUid,
            style: pw.TextStyle(fontSize: titleSize, fontWeight: pw.FontWeight.bold),
            maxLines: 1,
          ),
          pw.SizedBox(height: 2),
          pw.Text('Order: ${box.orderNumber}', style: pw.TextStyle(fontSize: textSize), maxLines: 1),
          pw.Text('Batch: ${box.batchNumber}', style: pw.TextStyle(fontSize: textSize), maxLines: 1),
          pw.Text('Exp: ${BoxItem.dateOnly(box.expiryDate)}', style: pw.TextStyle(fontSize: textSize), maxLines: 1),
        ],
      ),
    );
  }

  static PdfPageFormat _a4WithMargin() {
    const m = 10 * PdfPageFormat.mm;
    return PdfPageFormat.a4.copyWith(
      marginLeft: m,
      marginRight: m,
      marginTop: m,
      marginBottom: m,
    );
  }
}
