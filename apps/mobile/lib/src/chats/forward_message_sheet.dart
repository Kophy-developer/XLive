import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/media/media_url.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/api_friendly_messages.dart';
import '../../core/widgets/user_avatar.dart';
import '../../features/chats/chats_repository.dart';
import '../../features/chats/models/chat_api_models.dart';
import '../../features/groups/groups_repository.dart';
import 'chat_theme.dart';

class ForwardablePayload {
  const ForwardablePayload({
    this.content,
    this.mediaUrl,
    this.mediaType,
    this.isImage = false,
    this.isVideo = false,
    this.isAudio = false,
  });

  factory ForwardablePayload.fromMessage(ChatMessage message) {
    return ForwardablePayload(
      content: message.content,
      mediaUrl: message.mediaUrl,
      mediaType: message.mediaType,
      isImage: message.isImage,
      isVideo: message.isVideo,
      isAudio: message.isAudio,
    );
  }

  final String? content;
  final String? mediaUrl;
  final String? mediaType;
  final bool isImage;
  final bool isVideo;
  final bool isAudio;

  bool get hasMedia => mediaUrl != null && mediaUrl!.trim().isNotEmpty;

  bool get canForward {
    final text = content?.trim() ?? '';
    return text.isNotEmpty || hasMedia;
  }

  String get previewLabel {
    final text = content?.trim() ?? '';
    if (text.isNotEmpty) return text;
    if (isAudio) return 'Voice note';
    if (isVideo) return 'Video';
    if (isImage) return 'Photo';
    return 'Message';
  }
}

Future<bool?> showForwardMessageSheet(
  BuildContext context, {
  required ForwardablePayload message,
  String? excludeChatId,
  String? excludeGroupId,
}) {
  if (!message.canForward) return Future.value(false);
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _ForwardMessageSheet(
      message: message,
      excludeChatId: excludeChatId,
      excludeGroupId: excludeGroupId,
    ),
  );
}

class _ForwardMessageSheet extends StatefulWidget {
  const _ForwardMessageSheet({
    required this.message,
    this.excludeChatId,
    this.excludeGroupId,
  });

  final ForwardablePayload message;
  final String? excludeChatId;
  final String? excludeGroupId;

  @override
  State<_ForwardMessageSheet> createState() => _ForwardMessageSheetState();
}

class _ForwardMessageSheetState extends State<_ForwardMessageSheet> {
  final _chatsRepo = ChatsRepository();
  final _groupsRepo = GroupsRepository();
  final _search = TextEditingController();

  List<ChatThread> _chats = const [];
  List<GroupSummary> _groups = const [];
  bool _loading = true;
  String? _error;
  String? _sendingTo;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _chatsRepo.listChats(limit: 50),
        _groupsRepo.listMyGroups(limit: 50),
      ]);
      if (!mounted) return;
      final chats = (results[0] as List<ChatThread>)
          .where((c) => c.id.isNotEmpty && c.id != widget.excludeChatId)
          .toList();
      final groups = (results[1] as List<GroupSummary>)
          .where((g) => g.id.isNotEmpty && g.id != widget.excludeGroupId)
          .toList();
      setState(() {
        _chats = chats;
        _groups = groups;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyApiMessage(e, fallback: 'Could not load conversations.');
      });
    }
  }

  List<ChatThread> get _filteredChats {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _chats;
    return _chats.where((c) {
      final name = (c.otherUser?.name ?? '').toLowerCase();
      final preview = (c.preview ?? '').toLowerCase();
      return name.contains(q) || preview.contains(q);
    }).toList();
  }

  List<GroupSummary> get _filteredGroups {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _groups;
    return _groups.where((g) {
      final name = g.name.toLowerCase();
      final preview = (g.preview ?? '').toLowerCase();
      return name.contains(q) || preview.contains(q);
    }).toList();
  }

  Future<void> _forwardToChat(ChatThread chat) async {
    if (_sendingTo != null) return;
    setState(() => _sendingTo = 'chat:${chat.id}');
    try {
      await _deliver(
        sendText: (content) => _chatsRepo.sendMessage(chat.id, content: content),
        sendMedia: ({
          required String filePath,
          required String filename,
          String? content,
          String? mediaType,
        }) =>
            _chatsRepo.uploadMessageFile(
              chat.id,
              filePath: filePath,
              filename: filename,
              content: content,
              mediaType: mediaType,
            ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingTo = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  Future<void> _forwardToGroup(GroupSummary group) async {
    if (_sendingTo != null) return;
    setState(() => _sendingTo = 'group:${group.id}');
    try {
      await _deliver(
        sendText: (content) => _groupsRepo.sendGroupMessage(group.id, content: content),
        sendMedia: ({
          required String filePath,
          required String filename,
          String? content,
          String? mediaType,
        }) =>
            _groupsRepo.uploadMessageFile(
              group.id,
              filePath: filePath,
              filename: filename,
              content: content,
              mediaType: mediaType,
            ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingTo = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  Future<void> _deliver({
    required Future<void> Function(String content) sendText,
    required Future<void> Function({
      required String filePath,
      required String filename,
      String? content,
      String? mediaType,
    }) sendMedia,
  }) async {
    final payload = widget.message;
    final text = payload.content?.trim() ?? '';

    if (payload.hasMedia) {
      final file = await _downloadMedia(payload.mediaUrl!);
      if (file == null) {
        if (text.isNotEmpty) {
          await sendText(text);
          return;
        }
        throw ApiException('Could not copy media to forward.');
      }
      try {
        final filename = file.path.split(Platform.pathSeparator).last;
        final mediaType = payload.isAudio
            ? (payload.mediaType ?? 'voice')
            : payload.isVideo
                ? (payload.mediaType ?? 'video')
                : (payload.mediaType ?? 'image');
        await sendMedia(
          filePath: file.path,
          filename: filename.isEmpty ? 'forward.bin' : filename,
          content: text.isEmpty ? null : text,
          mediaType: mediaType,
        );
      } finally {
        if (await file.exists()) await file.delete();
      }
      return;
    }

    if (text.isEmpty) {
      throw ApiException('Nothing to forward.');
    }
    await sendText(text);
  }

  Future<File?> _downloadMedia(String rawUrl) async {
    final url = resolveMediaUrl(rawUrl);
    if (url.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 45));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final dir = await getTemporaryDirectory();
      final uri = Uri.parse(url);
      var name = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'forward.bin';
      name = name.split('?').first;
      if (name.isEmpty || !name.contains('.')) {
        if (widget.message.isAudio) {
          name = 'voice_note.m4a';
        } else if (widget.message.isVideo) {
          name = 'video.mp4';
        } else {
          name = 'photo.jpg';
        }
      }
      final file = File('${dir.path}/fwd_${DateTime.now().millisecondsSinceEpoch}_$name');
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return file;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final chats = _filteredChats;
    final groups = _filteredGroups;
    final empty = !_loading && _error == null && chats.isEmpty && groups.isEmpty;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(100)),
              ),
            ),
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Forward to', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ChatTheme.black)),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                widget.message.previewLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.3),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search chats and groups',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: const Color(0xFFF4F4F6),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                TextButton(onPressed: _load, child: const Text('Retry')),
                              ],
                            ),
                          ),
                        )
                      : empty
                          ? Center(
                              child: Text(
                                _query.trim().isEmpty ? 'No conversations yet' : 'No matches',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            )
                          : ListView(
                              padding: EdgeInsets.fromLTRB(8, 4, 8, 12 + bottom),
                              children: [
                                if (chats.isNotEmpty) ...[
                                  _sectionLabel('Chats'),
                                  ...chats.map((c) {
                                    final key = 'chat:${c.id}';
                                    final busy = _sendingTo == key;
                                    return ListTile(
                                      leading: UserAvatar(
                                        radius: 22,
                                        imageUrl: c.otherUser?.avatarUrl,
                                      ),
                                      title: Text(
                                        c.otherUser?.name ?? 'Chat',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                      subtitle: c.preview == null || c.preview!.isEmpty
                                          ? null
                                          : Text(c.preview!, maxLines: 1, overflow: TextOverflow.ellipsis),
                                      trailing: busy
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                                      onTap: _sendingTo != null ? null : () => _forwardToChat(c),
                                    );
                                  }),
                                ],
                                if (groups.isNotEmpty) ...[
                                  _sectionLabel('Groups'),
                                  ...groups.map((g) {
                                    final key = 'group:${g.id}';
                                    final busy = _sendingTo == key;
                                    return ListTile(
                                      leading: UserAvatar(radius: 22, imageUrl: g.iconUrl),
                                      title: Text(
                                        g.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                      subtitle: Text(
                                        '${g.memberCount} members',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: busy
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                                      onTap: _sendingTo != null ? null : () => _forwardToGroup(g),
                                    );
                                  }),
                                ],
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: Colors.grey.shade600),
      ),
    );
  }
}
