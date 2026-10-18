import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/theme.dart';

/// "Ask the coach" a plain-language assessment of a position. Not Gold-gated: checked the
/// web's own explainPosition and its UI -- neither has a tier check anywhere, despite the
/// spec calling this feature "Gold". Matches the real behaviour, not the label.
Future<void> askAiCoach(BuildContext context, String fen) async {
  String? markdown;
  String? error;
  var loading = true;

  Future<void> load() async {
    try {
      final r = await Api.instance.post('/coach/explain', {'fen': fen}) as Map;
      markdown = r['markdown'] as String?;
      error = r['error'] as String?;
    } on ApiError catch (e) {
      error = e.message;
    }
  }

  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        if (loading) {
          load().then((_) {
            loading = false;
            setState(() {});
          });
        }
        final hc = ctx.hc;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(HcSpace.s4),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Ask the coach', style: HcText.titleMd.copyWith(color: hc.ink)),
                const SizedBox(height: HcSpace.s3),
                if (loading)
                  const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                else if (error != null)
                  Text(error!, style: HcText.bodySm.copyWith(color: hc.dangerInk))
                else
                  Text(markdown ?? '', style: HcText.body.copyWith(color: hc.ink)),
                const SizedBox(height: HcSpace.s3),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
                ),
              ]),
            ),
          ),
        );
      },
    ),
  );
}
