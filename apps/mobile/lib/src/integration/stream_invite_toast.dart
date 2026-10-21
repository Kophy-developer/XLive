import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_json.dart';
import '../../core/socket/xlive_socket_client.dart';
import '../../features/streams/models/stream_models.dart';
import '../../features/streams/streams_repository.dart';
import '../live/widgets/stream_invite_dialog.dart';

class StreamInviteToastHost extends StatefulWidget {
  const StreamInviteToastHost({super.key, required this.child});

  final Widget child;

  @override
  State<StreamInviteToastHost> createState() => _StreamInviteToastHostState();
}

class _StreamInviteToastHostState extends State<StreamInviteToastHost> {
  final _streamsRepo = StreamsRepository();
  StreamSubscription<Map<String, dynamic>>? _inviteSub;
  final Set<String> _shown = {};

  @override
  void initState() {
    super.initState();
    _inviteSub = XLiveSocketClient.instance.onStreamInviteIncoming.listen(_showInvite);
  }

  @override
  void dispose() {
    _inviteSub?.cancel();
    super.dispose();
  }

  Future<void> _showInvite(Map<String, dynamic> data) async {
    if (!mounted) return;
    final inviteId = ApiJson.pickString(data, ['inviteId', 'id', '_id']) ?? '';
    if (inviteId.isEmpty || _shown.contains(inviteId)) return;
    _shown.add(inviteId);

    StreamInvite invite;
    try {
      final mine = await _streamsRepo.myInvites(limit: 30);
      invite = mine.firstWhere(
        (i) => i.id == inviteId,
        orElse: () => StreamInvite.fromJson(data),
      );
      if (invite.id.isEmpty) {
        invite = StreamInvite.fromJson({...data, 'id': inviteId, 'status': 'pending'});
      }
    } catch (_) {
      invite = StreamInvite.fromJson({...data, 'id': inviteId, 'status': 'pending'});
    }
    if (!mounted) return;
    HapticFeedback.vibrate();
    await showStreamInviteAcceptDialog(context, invite: invite);
    _shown.remove(inviteId);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
