import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/theme.dart';
import 'certificate_pdf.dart';

/// "A PDF certificate for each level completed, with a QR code that verifies it." Lists
/// GET /certificates (one per completed course unit); viewing one renders the PDF
/// on-device and opens the platform's share/print/save sheet.
class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key});

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  List<Map<String, dynamic>>? _certificates;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.instance.get('/certificates') as Map;
      final list = (r['certificates'] as List).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _certificates = list;
        _error = null;
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _view(Map<String, dynamic> certificate) async {
    final doc = await buildCertificatePdf(certificate);
    await Printing.layoutPdf(onLayout: (format) => doc.save(), name: '${certificate['piece_name']} certificate.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final certificates = _certificates;
    return Scaffold(
      appBar: AppBar(title: const Text('My certificates')),
      body: certificates == null
          ? Center(
              child: _error != null
                  ? Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))
                  : const CircularProgressIndicator(),
            )
          : certificates.isEmpty
              ? const EmptyState(
                  icon: Icons.workspace_premium_outlined,
                  title: 'No certificates yet',
                  body: 'Finish a level on the Course path to earn one.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(HcSpace.s4),
                    children: [
                      HcListGroup(children: [
                        for (final c in certificates)
                          HcListRow(
                            leading: Container(
                              width: HcSize.avatarMd,
                              height: HcSize.avatarMd,
                              decoration: BoxDecoration(color: hc.greenSoft, borderRadius: BorderRadius.circular(HcRadius.sm)),
                              alignment: Alignment.center,
                              child: Icon(Icons.workspace_premium_rounded, color: hc.green),
                            ),
                            title: '${c['piece_name']} level',
                            subtitle: c['unit_title'] as String,
                            trailing: Icon(Icons.chevron_right_rounded, color: hc.ink3),
                            onTap: () => _view(c),
                          ),
                      ]),
                    ],
                  ),
                ),
    );
  }
}
