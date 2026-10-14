import 'package:flutter/material.dart';

import 'api.dart';
import 'theme.dart';

/// Shows the report dialog for [targetType]/[targetId] (matching POST /report's shape), fetching
/// the valid reasons from the server rather than hardcoding a copy of them in the app. Returns
/// true if a report was actually filed.
Future<bool> showReportDialog(
  BuildContext context, {
  required String targetType,
  required String targetId,
}) async {
  List<Map<String, dynamic>>? reasons;
  try {
    final r = await Api.instance.get('/report/reasons') as List;
    reasons = r.cast<Map<String, dynamic>>();
  } on ApiError catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
  if (!context.mounted) return false;
  return await showDialog<bool>(
        context: context,
        builder: (_) => _ReportDialog(targetType: targetType, targetId: targetId, reasons: reasons!),
      ) ??
      false;
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.targetType, required this.targetId, required this.reasons});
  final String targetType;
  final String targetId;
  final List<Map<String, dynamic>> reasons;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String? _reason;
  final _details = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) {
      setState(() => _error = 'Pick a reason.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await Api.instance.post('/report', {
        'targetType': widget.targetType,
        'targetId': widget.targetId,
        'reason': reason,
        if (_details.text.trim().isNotEmpty) 'details': _details.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RadioGroup<String>(
            groupValue: _reason,
            onChanged: (v) => setState(() => _reason = v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final r in widget.reasons)
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(r['label'] as String),
                    value: r['id'] as String,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _details,
            maxLength: 1000,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Anything else that would help (optional)', isDense: true),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: context.hc.dangerInk))),
        ],
      ),
      actions: [
        TextButton(onPressed: _sending ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: _sending ? null : _submit, child: const Text('Submit report')),
      ],
    );
  }
}
