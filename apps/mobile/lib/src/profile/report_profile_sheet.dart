import 'package:flutter/material.dart';

import '../../core/network/api_friendly_messages.dart';
import '../../core/report/formsubmit_report.dart';
import '../../core/session/auth_session.dart';

Future<void> showReportProfileSheet(
  BuildContext context, {
  required String reportedUserId,
  required String reportedHandle,
  String? reportedName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ReportProfileSheet(
      reportedUserId: reportedUserId,
      reportedHandle: reportedHandle,
      reportedName: reportedName,
    ),
  );
}

class _ReportProfileSheet extends StatefulWidget {
  const _ReportProfileSheet({
    required this.reportedUserId,
    required this.reportedHandle,
    this.reportedName,
  });

  final String reportedUserId;
  final String reportedHandle;
  final String? reportedName;

  @override
  State<_ReportProfileSheet> createState() => _ReportProfileSheetState();
}

class _ReportProfileSheetState extends State<_ReportProfileSheet> {
  final _reason = TextEditingController();
  bool _sending = false;
  String? _error;
  bool _sent = false;

  static const _purple = Color(0xFF8A3FFC);
  static const _black = Color(0xFF0A0A0A);

  String get _handle {
    final raw = widget.reportedHandle.trim();
    if (raw.isEmpty) return '@user';
    return raw.startsWith('@') ? raw : '@$raw';
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final me = AuthSession.instance.user;
      await sendProfileReport(
        reportedUserId: widget.reportedUserId,
        reportedHandle: _handle,
        reportedName: widget.reportedName,
        reason: _reason.text,
        reporterId: me?.id,
        reporterHandle: me?.username,
      );
      if (!mounted) return;
      setState(() {
        _sent = true;
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = friendlyApiMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final ready = _reason.text.trim().length >= 8 && !_sending;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            if (_sent) ...[
              const Text('Report sent', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _black)),
              const SizedBox(height: 8),
              Text(
                'Thanks. We’ll review $_handle.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ] else ...[
              Text('Report $_handle', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _black)),
              const SizedBox(height: 6),
              Text(
                'What did this account do?',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reason,
                minLines: 3,
                maxLines: 4,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 15, color: _black, height: 1.35),
                decoration: InputDecoration(
                  hintText: 'Tell us what happened',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                  filled: true,
                  fillColor: const Color(0xFFF4F4F6),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Color(0xFFEF003B), fontSize: 13, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 14),
              FilledButton(
                onPressed: ready ? _submit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _purple.withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: Text(_sending ? 'Sending…' : 'Send report', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
