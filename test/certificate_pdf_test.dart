import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/learn/certificate_pdf.dart';

void main() {
  test('builds a one-page PDF with real bytes', () async {
    final doc = await buildCertificatePdf({
      'id': 'cert-1',
      'piece_name': 'Pawn',
      'unit_title': 'The Board & Setup',
      'player_name': 'tester',
      'issued_at': '2026-01-01T00:00:00Z',
    });
    final bytes = await doc.save();
    expect(bytes.length, greaterThan(100));
    // PDFs start with the %PDF- magic bytes.
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
