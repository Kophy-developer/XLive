import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/live/live_now_store.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/api_friendly_messages.dart';
import '../../core/media/media_url.dart';
import '../../core/i18n/translation_service.dart';
import '../../core/utils/safe_text.dart';
import '../../core/widgets/connection_status_pill.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/socket/xlive_socket_client.dart';
import '../../features/chats/chats_repository.dart';
import '../../features/chats/models/chat_api_models.dart';
import '../../features/users/users_repository.dart';
import '../../core/users/presence.dart';
import '../integration/call_screens.dart';
import '../profile/user_profile_preview_screens.dart';
import 'chat_album.dart';
import 'chat_attach_utils.dart';
import 'chat_composer.dart';
import 'chat_date_utils.dart';
import 'chat_emoji.dart';
import 'chat_media_compose.dart';
import 'chat_theme.dart';
import 'expandable_chat_text.dart';
import 'emoji_reaction_sheet.dart';
import 'forward_message_sheet.dart';
import 'message_actions_sheet.dart';
import '../media/chat_image_prepare.dart';
import '../media/freeform_image_crop.dart';
import '../media/media_picker_utils.dart';

class DmChatScreen extends StatefulWidget {
  const DmChatScreen({
    super.key,
    required this.chatId,
    required this.peerName,
    required this.peerAvatarUrl,
    this.peerUserId,
    this.online = false,
  });

  final String chatId;
  final String peerName;
  final String peerAvatarUrl;
  final String? peerUserId;
  final bool online;

  @override
  State<DmChatScreen> createState() => _DmChatScreenState();
}

class _DmChatScreenState extends State<DmChatScreen> {
  final _chatsRepo = ChatsRepository();
  final _settings = SettingsRepository();
  final _usersRepo = UsersRepository();
  final _input = TextEditingController();
  final Map<String, String> _translations = {};
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightMessageId;
  List<ChatMessage> _messages = const [];
  final Set<String> _removedMessageIds = <String>{};
  final List<ChatPendingUpload> _pendingUploads = [];
  bool _loading = true;
  bool _peerBlocked = false;
  String? _error;
  StreamSubscription<Map<String, dynamic>>? _socketSub;
  StreamSubscription<Map<String, dynamic>>? _editedSub;
  StreamSubscription<Map<String, dynamic>>? _deletedSub;
  StreamSubscription<Map<String, dynamic>>? _reactionSub;
  StreamSubscription<Map<String, dynamic>>? _presenceSub;
  ChatMessage? _replyTarget;
  bool _peerOnline = false;
  String? _presenceLabel;
  Timer? _backgroundRefreshTimer;
  bool _isSending = false;
  bool _searchOpen = false;
  String _searchQuery = '';
  final _searchField = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _peerOnline = widget.online;
    _presenceLabel = widget.online ? 'Online' : null;
    _loadMessages();
    _loadPeerBlockStatus();
    _loadPresence();
    unawaited(LiveNowStore.instance.refresh());
    _chatsRepo.markRead(widget.chatId).ignore();
    _backgroundRefreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        _loadMessages();
      }
    });
    final socket = XLiveSocketClient.instance;
    _socketSub = socket.onDmMessage.listen((data) {
      final chatId = data['chatId']?.toString() ??
          data['dmChatId']?.toString() ??
          (data['message'] is Map ? (data['message'] as Map)['chatId']?.toString() : null) ??
          (data['data'] is Map ? (data['data'] as Map)['chatId']?.toString() : null);
      if (chatId != null && chatId.isNotEmpty && chatId != widget.chatId) return;
      _loadMessages();
    });
    _editedSub = socket.onMessageEdited.listen((data) {
      if (data['chatId']?.toString() != widget.chatId) return;
      final id = data['messageId']?.toString() ?? data['id']?.toString() ?? data['_id']?.toString();
      final content = data['content']?.toString() ?? data['text']?.toString();
      if (id != null && id.isNotEmpty && content != null) {
        _applyEditedLocally(id, content);
      }
      _loadMessages();
    });
    _deletedSub = socket.onMessageDeleted.listen((data) {
      if (data['chatId']?.toString() != widget.chatId) return;
      final id = data['messageId']?.toString() ?? data['id']?.toString() ?? data['_id']?.toString();
      if (id != null && id.isNotEmpty) {
        _removedMessageIds.add(id);
        _removeMessageLocally(id);
      } else {
        _loadMessages();
      }
    });
    _reactionSub = socket.onMessageReaction.listen((data) {
      if (data['chatId']?.toString() != widget.chatId) return;
      _loadMessages();
    });
    _presenceSub = socket.onUserPresenceChanged.listen((data) {
      final peerId = widget.peerUserId?.trim();
      if (peerId == null || peerId.isEmpty) return;
      final id = data['userId']?.toString() ?? data['id']?.toString() ?? data['_id']?.toString();
      if (id != peerId) return;
      _applyPresence(data);
    });
  }

  @override
  void dispose() {
    _backgroundRefreshTimer?.cancel();
    _searchDebounce?.cancel();
    _socketSub?.cancel();
    _editedSub?.cancel();
    _deletedSub?.cancel();
    _reactionSub?.cancel();
    _presenceSub?.cancel();
    _input.dispose();
    _searchField.dispose();
    super.dispose();
  }

  Future<void> _loadPresence() async {
    final peerId = widget.peerUserId?.trim();
    if (peerId == null || peerId.isEmpty) return;
    try {
      final data = await _usersRepo.getPresence(peerId);
      if (!mounted) return;
      _applyPresence(data);
    } catch (_) {}
  }

  void _applyPresence(Map<String, dynamic> data) {
    final parsed = parsePresence(data);
    setState(() {
      _peerOnline = parsed.online;
      _presenceLabel = parsed.label;
    });
  }

  GlobalKey _keyForMessage(String id) => _messageKeys.putIfAbsent(id, GlobalKey.new);

  Future<void> _scrollToMessage(String? messageId) async {
    if (messageId == null || messageId.isEmpty) return;
    final exists = _messages.any((m) => m.id == messageId);
    if (!exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Original message is not available')),
      );
      return;
    }
    final rows = coalesceChatImageAlbums(_messages, newestFirst: true);
    final keyId = resolveChatAlbumKeyId(rows, messageId);
    final ctx = _keyForMessage(keyId).currentContext;
    if (ctx == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Original message is not available')),
      );
      return;
    }
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.35,
    );
    if (!mounted) return;
    setState(() => _highlightMessageId = keyId);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    if (_highlightMessageId == keyId) {
      setState(() => _highlightMessageId = null);
    }
  }

  Future<void> _loadPeerBlockStatus() async {
    final peerId = widget.peerUserId;
    if (peerId == null || peerId.isEmpty) return;
    try {
      final blocked = await _settings.isUserBlocked(peerId);
      if (!mounted) return;
      setState(() => _peerBlocked = blocked);
    } catch (_) {}
  }

  Future<void> _handleChatError(Object e) async {
    if (e is ApiException && (e.statusCode == 400 || isBlockedUserError(e))) {
      await _loadPeerBlockStatus();
      if (!mounted) return;
      if (_peerBlocked || isBlockedUserError(e)) {
        setState(() => _peerBlocked = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This user is blocked. You cannot chat with them.')),
        );
        return;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(friendlyApiMessage(e))),
    );
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _chatsRepo.getMessages(widget.chatId);
      Map<String, List<MessageReaction>> reactions = const {};
      try {
        reactions = await _chatsRepo.getReactions(widget.chatId);
      } catch (_) {}
      final merged = reactions.isEmpty
          ? messages
          : messages.map((m) => reactions.containsKey(m.id) ? m.copyWith(reactions: reactions[m.id]) : m).toList();
      if (!mounted) return;
      final seenIds = <String>{};
      final unique = <ChatMessage>[];
      for (final m in merged) {
        if (m.id.isNotEmpty && !seenIds.add(m.id)) continue;
        unique.add(m);
      }
      final visible = unique.where((m) => !_removedMessageIds.contains(m.id)).toList();
      _removedMessageIds.removeWhere((id) => !merged.any((m) => m.id == id));
      setState(() {
        _messages = visible;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      var blocked = e is ApiException && isBlockedUserError(e);
      if (e is ApiException && e.statusCode == 400) {
        await _loadPeerBlockStatus();
        blocked = _peerBlocked;
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _peerBlocked = blocked || _peerBlocked;
        _error = blocked
            ? 'This user is blocked. You cannot chat with them.'
            : friendlyApiMessage(e, fallback: 'Could not load messages.');
      });
    }
  }

  Future<void> _send() async {
    if (_isSending) return;
    final t = _input.text.trim();
    if (t.isEmpty) return;
    if (isChatMessageTooLong(t)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(chatMessageTooLongMessage)));
      return;
    }
    final replyId = _replyTarget?.id;
    _input.clear();
    setState(() {
      _replyTarget = null;
      _isSending = true;
    });
    try {
      await _chatsRepo.sendMessage(widget.chatId, content: t, replyToMessageId: replyId);
      await _loadMessages();
    } catch (e) {
      if (!mounted) return;
      _handleChatError(e);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String _replyBannerLabel(ChatMessage message) {
    final text = message.content?.trim() ?? '';
    if (text.isNotEmpty) {
      return truncateSafely(text, 48);
    }
    if (message.isAudio) return 'Voice note';
    if (message.isVideo) return 'Video';
    if (message.isImage) return 'Photo';
    return 'Message';
  }

  Future<void> _forwardMessage(ChatMessage message) async {
    final ok = await showForwardMessageSheet(
      context,
      message: ForwardablePayload.fromMessage(message),
      excludeChatId: widget.chatId,
    );
    if (!mounted || ok != true) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Forwarded')));
  }

  Future<void> _toggleReaction(ChatMessage message, String rawEmoji) async {
    final emoji = sanitizeEmoji(rawEmoji);
    if (emoji == null) return;
    HapticFeedback.selectionClick();
    final existing = message.reactions.where((r) => r.emoji == emoji).toList();
    final alreadyMine = existing.isNotEmpty && existing.first.mine;
    try {
      if (alreadyMine) {
        await _chatsRepo.removeReaction(widget.chatId, message.id, emoji: emoji);
      } else {
        await _chatsRepo.addReaction(widget.chatId, message.id, emoji: emoji);
      }
      await _loadMessages();
    } catch (e) {
      if (!mounted) return;
      _handleChatError(e);
    }
  }

  Future<void> _showMessageActions(ChatMessage message) async {
    final hasText = message.content?.trim().isNotEmpty ?? false;
    final action = await showMessageActionsSheet(
      context,
      canEdit: message.isMine && hasText && !message.hasMedia,
      canDelete: message.isMine,
      canTranslate: hasText,
      canForward: ForwardablePayload.fromMessage(message).canForward,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case MessageAction.reply:
        setState(() => _replyTarget = message);
        break;
      case MessageAction.forward:
        await _forwardMessage(message);
        break;
      case MessageAction.react:
        final emoji = await showEmojiReactionPicker(context);
        if (emoji != null) await _toggleReaction(message, emoji);
        break;
      case MessageAction.copy:
        await copyMessageText(context, message.content ?? '');
        break;
      case MessageAction.translate:
        await _translateMessage(message);
        break;
      case MessageAction.edit:
        await _editMessage(message);
        break;
      case MessageAction.delete:
        await _deleteMessage(message);
        break;
    }
  }

  Future<void> _translateMessage(ChatMessage message) async {
    if (_translations.containsKey(message.id)) {
      setState(() => _translations.remove(message.id));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Translating…'), duration: Duration(milliseconds: 800)));
    final result = await TranslationService.instance.translate(message.content ?? '');
    if (!mounted) return;
    if (!result.translated) {
      messenger.showSnackBar(const SnackBar(content: Text('Already in your language or unavailable offline.')));
      return;
    }
    setState(() => _translations[message.id] = result.text);
  }

  Future<void> _editMessage(ChatMessage message) async {
    final text = await showEditMessageDialog(context, initial: message.content ?? '');
    if (text == null || text.trim().isEmpty || text.trim() == (message.content ?? '').trim()) return;
    if (isChatMessageTooLong(text)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(chatMessageTooLongMessage)));
      return;
    }
    _applyEditedLocally(message.id, text.trim());
    try {
      await _chatsRepo.editMessage(widget.chatId, message.id, content: text.trim());
      await _loadMessages();
    } catch (e) {
      if (!mounted) return;
      await _loadMessages();
      _handleChatError(e);
    }
  }

  void _applyEditedLocally(String messageId, String newContent) {
    if (!mounted) return;
    setState(() {
      _messages = [
        for (final m in _messages)
          if (m.id == messageId)
            m.copyWith(content: newContent, editedAt: DateTime.now())
          else
            m,
      ];
      _translations.remove(messageId);
    });
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    final confirm = await confirmDeleteMessage(context);
    if (confirm != true) return;
    _removedMessageIds.add(message.id);
    _removeMessageLocally(message.id);
    try {
      await _chatsRepo.deleteMessage(widget.chatId, message.id);
    } catch (e) {
      if (!mounted) return;
      _removedMessageIds.remove(message.id);
      await _loadMessages();
      _handleChatError(e);
    }
  }

  void _removeMessageLocally(String messageId) {
    if (!mounted) return;
    setState(() {
      _messages = _messages.where((m) => m.id != messageId).toList();
      _translations.remove(messageId);
    });
  }

  Future<void> _sendSticker(String emoji) async {
    final replyId = _replyTarget?.id;
    setState(() => _replyTarget = null);
    try {
      await _chatsRepo.sendMessage(widget.chatId, content: emoji, replyToMessageId: replyId);
      await _loadMessages();
    } catch (e) {
      if (!mounted) return;
      _handleChatError(e);
    }
  }

  Future<void> _attach() async {
    FocusScope.of(context).unfocus();
    final choice = await showChatAttachSheet(context);
    if (choice == null || !mounted) return;
    try {
      final pickedList = await pickChatAttachments(context, choice);
      if (pickedList.isEmpty || !mounted) return;
      final docs = pickedList.where((e) => e.isDocument).toList();
      for (final picked in docs) {
        if (!mounted) return;
        await _startDocumentUpload(picked);
      }
      final media = pickedList.where((e) => !e.isDocument).toList();
      if (media.isEmpty || !mounted) return;
      final prepared = <({String path, bool isVideo})>[];
      for (final picked in media) {
        if (!mounted) return;
        var path = picked.file.path;
        if (!picked.isVideo) {
          path = await prepareChatImageForUpload(path);
          if (!mounted) return;
          final cropped = await openFreeformImageCrop(context, path);
          if (cropped == null || !mounted) continue;
          path = cropped;
        }
        prepared.add((path: path, isVideo: picked.isVideo));
      }
      if (prepared.isEmpty || !mounted) return;
      final composedList = await openChatMediaComposeBatch(context, items: prepared);
      if (composedList == null || !mounted) return;
      final batches = planChatMediaSendBatches([
        for (final c in composedList) (path: c.path, isVideo: c.isVideo, caption: c.caption),
      ]);
      for (final batch in batches) {
        for (final item in batch.items) {
          if (!mounted) return;
          await _startMediaUpload(
            ChatMediaComposeResult(path: item.path, isVideo: item.isVideo, caption: item.caption),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      _handleChatError(e);
    }
  }

  Future<void> _startDocumentUpload(PickedGalleryMedia picked) async {
    final localId = 'doc_${DateTime.now().millisecondsSinceEpoch}';
    final replyId = _replyTarget?.id;
    if (_replyTarget != null) setState(() => _replyTarget = null);
    final pending = ChatPendingUpload(
      localId: localId,
      path: picked.file.path,
      isVideo: false,
      isDocument: true,
      caption: picked.file.name,
    );
    setState(() => _pendingUploads.insert(0, pending));
    try {
      final filename = picked.file.name.trim().isEmpty ? 'document.bin' : picked.file.name;
      final uploaded = await _chatsRepo.uploadMessageFile(
        widget.chatId,
        filePath: picked.file.path,
        filename: filename,
        content: filename,
        mediaType: 'document',
        replyToMessageId: replyId,
        onSendProgress: (sent, total) {
          if (!mounted) return;
          final i = _pendingUploads.indexWhere((u) => u.localId == localId);
          if (i < 0) return;
          setState(() => _pendingUploads[i].progress = total <= 0 ? 0 : (sent / total).clamp(0, 1));
        },
      );
      if (!mounted) return;
      final resolved = (uploaded.mediaUrl == null || uploaded.mediaUrl!.isEmpty)
          ? uploaded.copyWith(mediaUrl: picked.file.path, mediaType: 'document')
          : uploaded;
      setState(() {
        _pendingUploads.removeWhere((u) => u.localId == localId);
        _messages = [resolved, ..._messages.where((m) => m.id != resolved.id)];
      });
    } catch (e) {
      if (!mounted) return;
      final i = _pendingUploads.indexWhere((u) => u.localId == localId);
      if (i >= 0) setState(() => _pendingUploads[i].failed = true);
      _handleChatError(e);
    }
  }

  Future<void> _startMediaUpload(ChatMediaComposeResult composed) async {
    final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final replyId = _replyTarget?.id;
    if (_replyTarget != null) setState(() => _replyTarget = null);
    final pending = ChatPendingUpload(
      localId: localId,
      path: composed.path,
      isVideo: composed.isVideo,
      caption: composed.caption,
    );
    setState(() => _pendingUploads.insert(0, pending));

    try {
      final filename = composed.path.split(Platform.pathSeparator).last;
      final uploaded = await _chatsRepo.uploadMessageFile(
        widget.chatId,
        filePath: composed.path,
        filename: filename.isEmpty ? (composed.isVideo ? 'video.mp4' : 'photo.jpg') : filename,
        content: composed.caption,
        mediaType: composed.isVideo ? 'video' : 'image',
        replyToMessageId: replyId,
        onSendProgress: (sent, total) {
          if (!mounted) return;
          final i = _pendingUploads.indexWhere((u) => u.localId == localId);
          if (i < 0) return;
          setState(() => _pendingUploads[i].progress = total <= 0 ? 0 : (sent / total).clamp(0, 1));
        },
      );
      if (!mounted) return;
      final resolved = (uploaded.mediaUrl == null || uploaded.mediaUrl!.isEmpty)
          ? uploaded.copyWith(mediaUrl: composed.path, mediaType: composed.isVideo ? 'video' : 'image')
          : uploaded;
      setState(() {
        _pendingUploads.removeWhere((u) => u.localId == localId);
        _messages = [resolved, ..._messages.where((m) => m.id != resolved.id)];
      });
    } catch (e) {
      if (!mounted) return;
      final i = _pendingUploads.indexWhere((u) => u.localId == localId);
      if (i >= 0) setState(() => _pendingUploads[i].failed = true);
      _handleChatError(e);
    }
  }

  Future<void> _sendVoice(String path, int durationSeconds) async {
    final localId = 'vn_${DateTime.now().millisecondsSinceEpoch}';
    final replyId = _replyTarget?.id;
    if (_replyTarget != null) setState(() => _replyTarget = null);
    final pending = ChatPendingUpload(
      localId: localId,
      path: path,
      isVoice: true,
      durationSeconds: durationSeconds,
    );
    setState(() => _pendingUploads.insert(0, pending));
    try {
      final uploaded = await _chatsRepo.uploadMessageFile(
        widget.chatId,
        filePath: path,
        filename: 'voice_note.m4a',
        mediaType: 'voice',
        replyToMessageId: replyId,
        onSendProgress: (sent, total) {
          if (!mounted) return;
          final i = _pendingUploads.indexWhere((u) => u.localId == localId);
          if (i < 0) return;
          setState(() => _pendingUploads[i].progress = total <= 0 ? 0 : (sent / total).clamp(0, 1));
        },
      );
      final file = File(path);
      if (await file.exists()) await file.delete();
      if (!mounted) return;
      setState(() {
        _pendingUploads.removeWhere((u) => u.localId == localId);
        _messages = [uploaded, ..._messages.where((m) => m.id != uploaded.id)];
      });
    } catch (e) {
      if (!mounted) return;
      final i = _pendingUploads.indexWhere((u) => u.localId == localId);
      if (i >= 0) setState(() => _pendingUploads[i].failed = true);
      _handleChatError(e);
    }
  }

  Future<void> _retryPending(ChatPendingUpload upload) async {
    setState(() {
      _pendingUploads.removeWhere((u) => u.localId == upload.localId);
    });
    if (upload.isVoice) {
      await _sendVoice(upload.path, upload.durationSeconds ?? 0);
      return;
    }
    await _startMediaUpload(
      ChatMediaComposeResult(path: upload.path, isVideo: upload.isVideo, caption: upload.caption),
    );
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchQuery = '';
        _searchField.clear();
      }
    });
  }

  Future<void> _runDmSearch(String query) async {
    final q = query.trim();
    if (q.length < 2) return;
    try {
      final hits = await _chatsRepo.searchChat(widget.chatId, query: q);
      if (!mounted || _searchQuery.trim() != q) return;
      if (hits.isNotEmpty) {
        final existing = _messages.map((m) => m.id).toSet();
        final missing = hits.where((m) => !existing.contains(m.id)).toList();
        if (missing.isNotEmpty) {
          setState(() => _messages = [..._messages, ...missing]);
        }
        unawaited(_scrollToMessage(hits.first.id));
      }
    } catch (_) {}
  }

  void _showPeerProfile() {
    final userId = widget.peerUserId;
    if (userId == null || userId.isEmpty) return;
    Navigator.pushNamed(
      context,
      '/profile/other-user',
      arguments: OtherUserProfileArgs(userId: userId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatTheme.chatBg,
      appBar: _searchOpen
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              foregroundColor: ChatTheme.black,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => Navigator.pop(context)),
              title: TextField(
                controller: _searchField,
                autofocus: true,
                onChanged: (v) {
                  setState(() => _searchQuery = v);
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(const Duration(milliseconds: 320), () {
                    unawaited(_runDmSearch(v));
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
              actions: [
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: _toggleSearch),
              ],
            )
          : AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: ChatTheme.black,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => Navigator.pop(context)),
        titleSpacing: 0,
        title: GestureDetector(
          onTap: _showPeerProfile,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(
                    radius: 18,
                    imageUrl: widget.peerAvatarUrl.isEmpty ? null : widget.peerAvatarUrl,
                    isLive: LiveNowStore.instance.isLive(widget.peerUserId),
                  ),
                  if (_peerOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.peerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ChatTheme.black)),
                    Text(
                      _presenceLabel ?? (_peerOnline ? 'Online' : 'Offline'),
                      style: TextStyle(
                        fontSize: 12,
                        color: _peerOnline ? const Color(0xFF16A34A) : Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ...dmChatCallActions(
            context: context,
            chatId: widget.chatId,
            peerName: widget.peerName,
            peerUserId: widget.peerUserId,
          ),
          IconButton(icon: const Icon(Icons.search_rounded), onPressed: _toggleSearch),
          if (widget.peerUserId != null && widget.peerUserId!.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) {
                if (v == 'profile') _showPeerProfile();
                if (v == 'search') _toggleSearch();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'search', child: Text('Search')),
                const PopupMenuItem(value: 'profile', child: Text('View profile')),
              ],
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: Column(
        children: [
          const ConnectionStatusPill(darkBackground: false),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _error != null
                    ? Center(child: Text(_error!, textAlign: TextAlign.center))
                    : (_messages.isEmpty && _pendingUploads.isEmpty)
                        ? _DmChatEmptyState(
                            peerName: widget.peerName,
                            avatarUrl: widget.peerAvatarUrl,
                            onWave: () => _sendSticker('👋'),
                          )
                        : Builder(builder: (context) {
                        final rows = coalesceChatImageAlbums(_messages, newestFirst: true);
                        return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        reverse: true,
                        itemCount: rows.length + _pendingUploads.length,
                        itemBuilder: (_, i) {
                          if (i < _pendingUploads.length) {
                            final pending = _pendingUploads[i];
                            final pendingBottom = (i > 0)
                                ? 2.0
                                : (_messages.isNotEmpty && _messages.first.isMine ? 2.0 : 6.0);
                            return Padding(
                              padding: EdgeInsets.only(bottom: pendingBottom),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: PendingMediaBubble(
                                  upload: pending,
                                  onRetry: pending.failed ? () => _retryPending(pending) : null,
                                ),
                              ),
                            );
                          }
                          final msgIndex = i - _pendingUploads.length;
                          final row = rows[msgIndex];
                          final m = row.message;
                          final albumMedia = row.isAlbum
                              ? [
                                  for (final item in row.mediaItems)
                                    ChatAlbumMediaItem(
                                      url: resolveMediaUrl(item.url, resourceType: item.isVideo ? 'video' : 'image'),
                                      isVideo: item.isVideo,
                                    ),
                                ].where((e) => e.url.isNotEmpty).toList()
                              : null;
                          final bubbleText = row.isAlbum
                              ? (row.caption ?? '')
                              : visibleChatCaption(m.content);
                          final translated = _translations[m.id];
                          final older = msgIndex + 1 < rows.length ? rows[msgIndex + 1].message : null;
                          final showDate = older == null || !sameChatCalendarDay(m.createdAt, older.createdAt);
                          final replyTap = m.replyToMessageId == null || m.replyToMessageId!.isEmpty
                              ? null
                              : () => _scrollToMessage(m.replyToMessageId);
                          final highlight =
                              _highlightMessageId != null && row.messageIds.contains(_highlightMessageId!);
                          final double bottomGap;
                          if (msgIndex == 0) {
                            if (_pendingUploads.isNotEmpty) {
                              bottomGap = m.isMine ? 2.0 : 8.0;
                            } else {
                              bottomGap = 4.0;
                            }
                          } else {
                            final newer = rows[msgIndex - 1].message;
                            final sameSenderAsNewer = (newer.isMine == m.isMine);
                            final hasDateBetween = !sameChatCalendarDay(newer.createdAt, m.createdAt);
                            bottomGap = (sameSenderAsNewer && !hasDateBetween) ? 2.0 : 8.0;
                          }
                          return KeyedSubtree(
                            key: _keyForMessage(m.id),
                            child: Padding(
                            padding: EdgeInsets.only(bottom: bottomGap),
                            child: Align(
                              alignment: m.isMine ? Alignment.centerRight : Alignment.centerLeft,
                              child: Column(
                                crossAxisAlignment: m.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                              if (showDate && m.createdAt != null) ChatDateSeparator(date: m.createdAt!),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                decoration: BoxDecoration(
                                  color: highlight ? const Color(0x338A2DDC) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: GestureDetector(
                                onLongPress: () => _showMessageActions(m),
                                child: m.isMine
                                    ? SentMessageBubble(
                                        text: bubbleText,
                                        timeLabel: m.timeLabel,
                                        showReadReceipt: true,
                                        imageUrl: !row.isAlbum && m.hasMedia && m.isImage
                                            ? resolveMediaUrl(m.mediaUrl, resourceType: 'image')
                                            : null,
                                        albumMedia: albumMedia,
                                        videoUrl: !row.isAlbum && m.hasMedia && m.isVideo
                                            ? resolveMediaUrl(m.mediaUrl, resourceType: 'video')
                                            : null,
                                        audioUrl: m.hasMedia && m.isAudio ? resolveMediaUrl(m.mediaUrl) : null,
                                        documentUrl: !row.isAlbum && m.hasMedia && m.isDocument ? resolveMediaUrl(m.mediaUrl) : null,
                                        documentName: m.content,
                                        isSticker: m.isSticker,
                                        reactions: m.reactions,
                                        onReactionTap: (e) => _toggleReaction(m, e),
                                        edited: m.isEdited,
                                        replySnippet: m.replySnippet,
                                        onReplyTap: replyTap,
                                      )
                                    : ReceivedMessageBubble(
                                        text: bubbleText,
                                        timeLabel: m.timeLabel,
                                        avatarUrl: m.senderAvatarUrl ?? widget.peerAvatarUrl,
                                        imageUrl: !row.isAlbum && m.hasMedia && m.isImage
                                            ? resolveMediaUrl(m.mediaUrl, resourceType: 'image')
                                            : null,
                                        albumMedia: albumMedia,
                                        videoUrl: !row.isAlbum && m.hasMedia && m.isVideo
                                            ? resolveMediaUrl(m.mediaUrl, resourceType: 'video')
                                            : null,
                                        audioUrl: m.hasMedia && m.isAudio ? resolveMediaUrl(m.mediaUrl) : null,
                                        documentUrl: !row.isAlbum && m.hasMedia && m.isDocument ? resolveMediaUrl(m.mediaUrl) : null,
                                        documentName: m.content,
                                        isSticker: m.isSticker,
                                        reactions: m.reactions,
                                        onReactionTap: (e) => _toggleReaction(m, e),
                                        onAvatarTap: _showPeerProfile,
                                        edited: m.isEdited,
                                        replySnippet: m.replySnippet,
                                        onReplyTap: replyTap,
                                      ),
                              ),
                              ),
                              if (translated != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                                  child: Container(
                                    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.7),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1ECFB),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.translate_rounded, size: 12, color: ChatTheme.purple),
                                            const SizedBox(width: 4),
                                            Text('Translated', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ChatTheme.purple)),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(translated, style: const TextStyle(fontSize: 14, color: ChatTheme.black)),
                                      ],
                                    ),
                                  ),
                                ),
                                ],
                              ),
                            ),
                          ),
                          );
                        },
                      );
                      }),
          ),
          if (_peerBlocked)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF1F1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                'This user is blocked. You cannot send messages.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red.shade700),
              ),
            ),
          IgnorePointer(
            ignoring: _peerBlocked,
            child: Opacity(
              opacity: _peerBlocked ? 0.45 : 1,
              child: ChatComposerBar(
                controller: _input,
                onSend: _send,
                onAttach: _attach,
                onSendSticker: _sendSticker,
                onSendVoice: _sendVoice,
                replyingLabel: _replyTarget != null ? 'Replying to: ${_replyBannerLabel(_replyTarget!)}' : null,
                onCancelReply: _replyTarget != null ? () => setState(() => _replyTarget = null) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DmChatEmptyState extends StatelessWidget {
  const _DmChatEmptyState({
    required this.peerName,
    required this.avatarUrl,
    required this.onWave,
  });

  final String peerName;
  final String avatarUrl;
  final VoidCallback onWave;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF8A2DDC), Color(0xFF35D3FB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8A2DDC).withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: UserAvatar(
                radius: 40,
                imageUrl: avatarUrl.isEmpty ? null : avatarUrl,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              peerName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: ChatTheme.black,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No messages here yet. Send a message or wave to start the conversation.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Material(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onWave,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('👋', style: TextStyle(fontSize: 18)),
                      SizedBox(width: 8),
                      Text(
                        'Say hello',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF8A2DDC),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}