import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _siteUrl = 'https://play.chess.hamduk.com.ng';

/// Renders one earned course-path certificate as a one-page PDF, with a QR code linking to
/// the public /certificate/{id} page -- anyone scanning it gets the server-authoritative
/// record, not just whatever this PDF says.
Future<pw.Document> buildCertificatePdf(Map<String, dynamic> certificate) async {
  final doc = pw.Document();
  final verifyUrl = '$_siteUrl/certificate/${certificate['id']}';
  final issuedAt = DateTime.tryParse(certificate['issued_at'] as String? ?? '') ?? DateTime.now();
  final issuedLabel = '${_month(issuedAt.month)} ${issuedAt.day}, ${issuedAt.year}';

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (context) => pw.Container(
        padding: const pw.EdgeInsets.all(40),
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 2, color: PdfColors.green800)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('HAMDUK CHESS', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.green800, letterSpacing: 2)),
            pw.SizedBox(height: 24),
            pw.Text('Certificate of Completion', style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 32),
            pw.Text('This certifies that', style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 8),
            pw.Text(certificate['player_name'] as String, style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Text(
              'completed the ${certificate['piece_name']} level (${certificate['unit_title']})',
              style: const pw.TextStyle(fontSize: 14),
              textAlign: pw.TextAlign.center,
            ),
            pw.Text('of the Hamduk Chess Course path.', style: const pw.TextStyle(fontSize: 14)),
            pw.Spacer(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Issued', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  pw.Text(issuedLabel, style: const pw.TextStyle(fontSize: 12)),
                ]),
                pw.Column(children: [
                  pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: verifyUrl, width: 64, height: 64),
                  pw.SizedBox(height: 4),
                  pw.Text('Scan to verify', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                ]),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return doc;
}

String _month(int m) => const [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ][m - 1];
