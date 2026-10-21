import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_friendly_messages.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../features/streams/models/stream_models.dart';
import '../../../features/streams/streams_repository.dart';
import '../live_stream_flow.dart';
import '../live_theme.dart';

Future<bool> showStreamInviteAcceptDialog(
  BuildContext context, {
  required StreamInvite invite,
  bool autoNavigateOnAccept = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _StreamInviteDialog(invite: invite),
  );
  if (result != true || !context.mounted) return result == true;
  if (autoNavigateOnAccept && invite.streamId != null && invite.streamId!.isNotEmpty) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == '/live/during') {
      Navigator.pushReplacementNamed(
        context,
        '/live/during',
        arguments: LiveDuringArgs(
          streamId: invite.streamId!,
          isCohost: invite.isCohostRole,
        ),
      );
    } else {
      Navigator.pushNamed(
        context,
        '/live/during',
        arguments: LiveDuringArgs(
          streamId: invite.streamId!,
          isCohost: invite.isCohostRole,
        ),
      );
    }
  }
  return true;
}

class _StreamInviteDialog extends StatefulWidget {
  const _StreamInviteDialog({required this.invite});

  final StreamInvite invite;

  @override
  State<_StreamInviteDialog> createState() => _StreamInviteDialogState();
}

class _StreamInviteDialogState extends State<_StreamInviteDialog> {
  final _repo = StreamsRepository();
  bool _busy = false;

  Future<void> _accept() async {
    if (_busy) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      await _repo.acceptInvite(widget.invite.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiMessage(e))));
    }
  }

  Future<void> _decline() async {
    if (_busy) return;
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    try {
      await _repo.declineInvite(widget.invite.id);
      if (!mounted) return;
      Navigator.pop(context, false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final invite = widget.invite;
    final host = invite.hostName ?? 'a creator';
    final title = invite.streamTitle ?? 'Live stream';
    final timing = invite.scheduleLabel;
    final roleLine = invite.isCohostRole ? 'as co-host' : 'as a viewer';
    return Dialog(
      backgroundColor: const Color(0xFF16161A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                UserAvatar(radius: 22, imageUrl: invite.inviteeAvatarUrl),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Stream invite',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '$host invited you to “$title”${timing == null ? '' : ' · $timing'} $roleLine.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 14.5, height: 1.4),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _decline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [LiveTheme.purple, Color(0xFFE8487E)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _busy ? null : _accept,
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 48,
                          child: Center(
                            child: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Accept', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
