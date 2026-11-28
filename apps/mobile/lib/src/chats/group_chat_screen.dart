import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_friendly_messages.dart';
import '../../core/media/media_url.dart';
import '../../core/i18n/translation_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/utils/safe_text.dart';
import '../../core/socket/xlive_socket_client.dart';
import '../../features/calls/calls_repository.dart';
import '../../features/calls/models/call_models.dart';
import '../../features/chats/models/chat_api_models.dart';
import '../../features/groups/groups_repository.dart';
import '../../core/widgets/connection_status_pill.dart';
import '../../core/widgets/user_avatar.dart';
import '../integration/call_screens.dart';
import '../media/chat_image_prepare.dart';
import '../media/freeform_image_crop.dart';
import '../media/media_picker_utils.dart';
import '../profile/user_profile_preview_screens.dart';
import '../social/social_api_screens.dart';
import 'chat_album.dart';
import 'chat_attach_utils.dart';
import 'chat_composer.dart';
import 'chat_date_utils.dart';
import 'chat_emoji.dart';
import 'chat_media_compose.dart';
import 'chat_theme.dart';
import 'emoji_reaction_sheet.dart';
import 'expandable_chat_text.dart';
import 'forward_message_sheet.dart';
import 'group_chat_bubbles.dart';
import 'group_dialogs_sheets.dart';
import 'group_media_gallery_screen.dart';
import 'group_preview_screen.dart';
import 'group_thread_models.dart';
import 'group_viewer_preview_sheet.dart';
import 'message_actions_sheet.dart';
import 'reactions_detail_sheet.dart';
import 'select_contact_screen.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({
    super.key,
    this.groupId,
    required this.groupName,
    required this.avatarUrl,
    this.followers = 0,
    this.showWelcome = false,
    this.viewerMode = false,
  });

  final String? groupId;
  final String groupName;
  final String avatarUrl;
  final int followers;
  final bool showWelcome;
  final bool viewerMode;

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> with WidgetsBindingObserver {
  final _groupsRepo = GroupsRepository();
  final _input = TextEditingController();
  final _searchField = TextEditingController();
  final _scrollController = ScrollController();
  late List<GroupThreadMessage> _messages;
  List<ChatMessage> _apiMessages = const [];
  final List<ChatPendingUpload> _pendingUploads = [];
  final Map<String, String> _translations = {};
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightMessageId;
  GroupThreadMessage? _replyTarget;
  ChatMessage? _apiReplyTarget;
  bool _searchOpen = false;
  String _searchQuery = '';
  int _searchHitIndex = 0;
  Timer? _searchDebounce;
  List<ChatMessage> _serverSearchHits = const [];
  bool _serverSearching = false;
  StreamSubscription<Map<String, dynamic>>? _socketSub;
  StreamSubscription<Map<String, dynamic>>? _reactionSub;
  StreamSubscription<Map<String, dynamic>>? _editedSub;
  StreamSubscription<Map<String, dynamic>>? _deletedSub;
  StreamSubscription<Map<String, dynamic>>? _groupCallStartedSub;
  Timer? _groupCallPollTimer;
  Timer? _messagePollTimer;
  bool _isSending = false;
  GroupCallEventPayload? _groupCallInvite;
  final _dismissedGroupCallIds = <String>{};
  final Set<String> _removedMessageIds = <String>{};
  final Map<String, String> _memberAvatarById = {};
  final Map<String, String> _memberNameById = {};
  bool _loadingMessages = false;
  bool _messagesReady = false;
  bool _historyHidden = false;

  bool get _useApi => widget.groupId != null && widget.groupId!.isNotEmpty;

  bool get _showJoinEmptyState =>
      _useApi &&
      _messagesReady &&
      !_loadingMessages &&
      _apiMessages.isEmpty &&
      _pendingUploads.isEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_useApi) {
      _messages = widget.showWelcome ? [] : [];
      _loadApiMessages();
      unawaited(_loadMemberAvatars());
      _setupGroupCallListeners();
      _groupsRepo.markGroupRead(widget.groupId!).ignore();
      _messagePollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (mounted && _useApi) {
          _loadApiMessages();
        }
      });
      _socketSub = XLiveSocketClient.instance.onGroupMessage.listen((data) {
        final gId = data['groupId']?.toString() ??
            data['chatId']?.toString() ??
            (data['message'] is Map ? (data['message'] as Map)['groupId']?.toString() : null) ??
            (data['data'] is Map ? (data['data'] as Map)['groupId']?.toString() : null);
        if (gId != null && gId.isNotEmpty && gId != widget.groupId) return;
        _loadApiMessages();
      });
      _reactionSub = XLiveSocketClient.instance.onGroupMessageReaction.listen((data) {
        if (data['groupId']?.toString() != widget.groupId) return;
        _loadApiMessages();
      });
      _editedSub = XLiveSocketClient.instance.onGroupMessageEdited.listen((data) {
        if (data['groupId']?.toString() != widget.groupId) return;
        final id = data['messageId']?.toString() ?? data['id']?.toString() ?? data['_id']?.toString();
        final content = data['content']?.toString() ?? data['text']?.toString();
        if (id != null && id.isNotEmpty && content != null) {
          _applyEditedLocally(id, content);
        }
        _loadApiMessages();
      });
      _deletedSub = XLiveSocketClient.instance.onGroupMessageDeleted.listen((data) {
        if (data['groupId']?.toString() != widget.groupId) return;
        final id = data['messageId']?.toString() ?? data['id']?.toString() ?? data['_id']?.toString();
        if (id != null && id.isNotEmpty) {
          _removedMessageIds.add(id);
          _removeMessageLocally(id);
        } else {
          _loadApiMessages();
        }
      });
    } else {
      _messages = widget.showWelcome ? [] : _defaultThread();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _useApi) {
      _pollActiveGroupCall();
    }
  }

  Future<void> _setupGroupCallListeners() async {
    if (!_useApi || widget.groupId == null) return;
    await ensureGroupCallSocketRooms(widget.groupId!);
    await _pollActiveGroupCall();
    _groupCallStartedSub = XLiveSocketClient.instance.onGroupCallStarted.listen(_onGroupCallStarted);
    _groupCallPollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _pollActiveGroupCall());
  }

  void _onGroupCallStarted(Map<String, dynamic> data) {
    final payload = GroupCallEventPayload.fromJson(data);
    if (payload.groupId != widget.groupId) return;
    if (payload.callId.isEmpty) return;
    if (_dismissedGroupCallIds.contains(payload.callId)) return;
    final me = AuthSession.instance.user?.id ?? XLiveSocketClient.instance.userId;
    final starter = payload.userId;
    if (starter != null && starter.isNotEmpty && me != null && starter == me) return;
    if (!mounted) return;
    setState(() => _groupCallInvite = payload);
  }

  Future<void> _pollActiveGroupCall() async {
    if (!_useApi || widget.groupId == null) return;
    try {
      final active = await CallsRepository().getActiveGroupCall(widget.groupId!);
      if (active == null || active.id.isEmpty) {
        if (mounted && _groupCallInvite != null) setState(() => _groupCallInvite = null);
        return;
      }
      if (_dismissedGroupCallIds.contains(active.id)) return;
      final me = AuthSession.instance.user?.id ?? XLiveSocketClient.instance.userId;
      final starter = active.peerUserId;
      if (starter != null && starter.isNotEmpty && me != null && starter == me) return;
      if (!mounted) return;
      setState(() => _groupCallInvite = GroupCallEventPayload(
            groupId: widget.groupId!,
            callId: active.id,
            callType: active.callType,
            groupName: widget.groupName,
            userId: starter,
          ));
    } catch (_) {}
  }

  void _joinActiveGroupCall() {
    final invite = _groupCallInvite;
    if (invite == null) return;
    setState(() => _groupCallInvite = null);
    joinOngoingGroupCall(
      context,
      groupId: widget.groupId!,
      groupName: widget.groupName,
      callType: invite.callType,
    );
  }

  void _dismissGroupCallInvite() {
    final invite = _groupCallInvite;
    if (invite == null) return;
    _dismissedGroupCallIds.add(invite.callId);
    setState(() => _groupCallInvite = null);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _groupCallStartedSub?.cancel();
    _groupCallPollTimer?.cancel();
    _messagePollTimer?.cancel();
    if (_useApi) {
      XLiveSocketClient.instance.leaveGroupChat(widget.groupId!);
    }
    _socketSub?.cancel();
    _reactionSub?.cancel();
    _editedSub?.cancel();
    _deletedSub?.cancel();
    _input.dispose();
    _searchField.dispose();
    _searchDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMemberAvatars() async {
    final groupId = widget.groupId;
    if (groupId == null || groupId.isEmpty) return;
    try {
      final members = await _groupsRepo.listMembers(groupId, limit: 100);
      if (!mounted) return;
      final avatars = <String, String>{};
      final names = <String, String>{};
      for (final m in members) {
        final url = m.avatarUrl?.trim();
        if (url != null && url.isNotEmpty) avatars[m.id] = url;
        final name = m.name.trim();
        if (name.isNotEmpty && name != 'Member') names[m.id] = name;
      }
      setState(() {
        _memberAvatarById
          ..clear()
          ..addAll(avatars);
        _memberNameById
          ..clear()
          ..addAll(names);
      });
    } catch (_) {}
  }

  ChatMessage _enrichMessageAvatar(ChatMessage m) {
    final id = m.senderId?.trim();
    if (id == null || id.isEmpty) return m;
    final existingAvatar = m.senderAvatarUrl?.trim();
    final existingName = m.senderName?.trim();
    final fromAvatar = _memberAvatarById[id];
    final fromName = _memberNameById[id];
    final nextAvatar = (existingAvatar == null || existingAvatar.isEmpty) ? fromAvatar : null;
    final nextName = (existingName == null || existingName.isEmpty || existingName == 'Member') ? fromName : null;
    if ((nextAvatar == null || nextAvatar.isEmpty) && (nextName == null || nextName.isEmpty)) return m;
    return m.copyWith(
      senderAvatarUrl: nextAvatar,
      senderName: nextName,
    );
  }

  Future<void> _loadApiMessages() async {
    if (!_useApi) return;
    if (!_messagesReady) {
      setState(() => _loadingMessages = true);
    }
    try {
      final items = await _groupsRepo.getGroupMessages(widget.groupId!);
      Map<String, List<MessageReaction>> reactions = const {};
      try {
        reactions = await _groupsRepo.getReactions(widget.groupId!);
      } catch (_) {}
      final merged = reactions.isEmpty
          ? items
          : items.map((m) => reactions.containsKey(m.id) ? m.copyWith(reactions: reactions[m.id]) : m).toList();
      final since = await _groupsRepo.resolveVisibleSince(widget.groupId!);
      if (!mounted) return;
      final seenIds = <String>{};
      final unique = <ChatMessage>[];
      for (final m in merged) {
        if (m.id.isNotEmpty && !seenIds.add(m.id)) continue;
        unique.add(m);
      }
      final visible = unique.where((m) => !_removedMessageIds.contains(m.id)).map(_enrichMessageAvatar).toList();
      _removedMessageIds.removeWhere((id) => !merged.any((m) => m.id == id));
      final shouldScroll = !_messagesReady ||
          (_scrollController.hasClients &&
              _scrollController.position.maxScrollExtent - _scrollController.position.pixels < 220);
      setState(() {
        _historyHidden = since != null;
        _apiMessages = visible.reversed.toList();
        _messages = visible.map(_mapApiMessage).toList().reversed.toList();
        _loadingMessages = false;
        _messagesReady = true;
      });
      if (shouldScroll && _apiMessages.isNotEmpty) _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMessages = false;
        _messagesReady = true;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  GroupThreadMessage _mapApiMessage(ChatMessage m) {
    final snippet = m.replySnippet;
    if (m.isMine) {
      return GroupThreadMessage.outgoing(id: m.id, text: m.content ?? '', time: m.timeLabel, replySnippet: snippet);
    }
    return GroupThreadMessage.incomingText(
      id: m.id,
      text: m.content ?? '',
      time: m.timeLabel,
      avatarUrl: m.senderAvatarUrl ?? '',
      senderName: m.senderName,
      senderId: m.senderId,
      replySnippet: snippet,
    );
  }

  Color _senderColorFor(String? senderId, String? senderName) {
    const palette = <Color>[
      Color(0xFF7C3AED),
      Color(0xFFDB2777),
      Color(0xFF0891B2),
      Color(0xFF059669),
      Color(0xFFD97706),
      Color(0xFF4F46E5),
      Color(0xFFDC2626),
      Color(0xFF0D9488),
    ];
    final key = (senderId?.trim().isNotEmpty == true ? senderId! : (senderName ?? '')).trim();
    if (key.isEmpty) return ChatTheme.purpleDeep;
    return palette[key.hashCode.abs() % palette.length];
  }

  bool _shouldShowSenderName(ChatMessage current, ChatMessage? previous) {
    if (current.isMine) return false;
    final name = current.senderName?.trim() ?? '';
    if (name.isEmpty) return false;
    if (previous == null || previous.isMine) return true;
    final prevId = previous.senderId?.trim() ?? '';
    final curId = current.senderId?.trim() ?? '';
    if (curId.isNotEmpty && prevId.isNotEmpty) return curId != prevId;
    return (previous.senderName?.trim() ?? '') != name;
  }

  Future<void> _sendApiMessage(String text, {String? replyToMessageId}) async {
    if (_isSending || !_useApi || widget.groupId == null) return;
    if (isChatMessageTooLong(text)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(chatMessageTooLongMessage)));
      return;
    }
    _isSending = true;
    try {
      await _groupsRepo.sendGroupMessage(widget.groupId!, content: text, replyToMessageId: replyToMessageId);
      await _loadApiMessages();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    } finally {
      _isSending = false;
    }
  }

  String _snippetForApiReply(ChatMessage m) {
    final text = m.content?.trim() ?? '';
    if (text.isNotEmpty) {
      return truncateSafely(text, 48);
    }
    if (m.isAudio) return 'Voice note';
    if (m.isVideo) return 'Video';
    if (m.isImage) return 'Photo';
    return 'Message';
  }

  Future<void> _forwardApiMessage(ChatMessage message) async {
    final ok = await showForwardMessageSheet(
      context,
      message: ForwardablePayload.fromMessage(message),
      excludeGroupId: widget.groupId,
    );
    if (!mounted || ok != true) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Forwarded')));
  }

  Future<void> _forwardDemoMessage(GroupThreadMessage msg) async {
    final text = msg.bodyText?.trim() ?? '';
    final payload = ForwardablePayload(
      content: text.isEmpty ? null : text,
      mediaUrl: msg.imageUrl,
      isImage: msg.kind == GroupThreadRowKind.incomingImage,
    );
    if (!payload.canForward) return;
    final ok = await showForwardMessageSheet(
      context,
      message: payload,
      excludeGroupId: widget.groupId,
    );
    if (!mounted || ok != true) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Forwarded')));
  }

  List<GroupThreadMessage> _defaultThread() {
    return [
      GroupThreadMessage.outgoing(id: 'm1', text: 'Lorem ipsum dolor sit amet,', time: '8:30 PM'),
      GroupThreadMessage.incomingImage(
        id: 'm2',
        imageUrl: '',
        time: '9:00 PM',
        avatarUrl: '',
        reactions: const [
          ReactionCount('❤️', 3),
          ReactionCount('💯', 1),
          ReactionCount('😍', 8),
        ],
        caption: 'Lorem ipsum dolor sit amet,',
      ),
      GroupThreadMessage.system(id: 'm3', text: 'Mark John Left'),
      GroupThreadMessage.incomingText(
        id: 'm4',
        text: 'Lorem ipsum dolor sit amet, consectetur adipig elit.',
        time: '6:10 PM',
        avatarUrl: '',
        replySnippet: 'Lorem ipsum dolor sit ame , consect....',
      ),
    ];
  }

  String _formatTime() {
    final n = TimeOfDay.now();
    final h = n.hourOfPeriod == 0 ? 12 : n.hourOfPeriod;
    final m = n.minute.toString().padLeft(2, '0');
    final ap = n.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  String _snippetForReply(GroupThreadMessage m) {
    switch (m.kind) {
      case GroupThreadRowKind.outgoingText:
        return m.bodyText ?? '';
      case GroupThreadRowKind.incomingText:
        return m.bodyText ?? '';
      case GroupThreadRowKind.incomingImage:
        final cap = m.bodyText;
        if (cap != null && cap.isNotEmpty) return cap;
        return 'Image';
      case GroupThreadRowKind.system:
        return m.systemText ?? '';
    }
  }

  List<int> get _searchHitIndices {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return [];
    final out = <int>[];
    final hitIds = _serverSearchHits.map((m) => m.id).toSet();
    for (var i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      final t = '${m.bodyText ?? ''} ${m.systemText ?? ''}'.toLowerCase();
      if (t.contains(q) || hitIds.contains(m.id)) out.add(i);
    }
    if (out.isEmpty && _useApi && hitIds.isNotEmpty) {
      for (var i = 0; i < _apiMessages.length; i++) {
        if (hitIds.contains(_apiMessages[i].id)) {
          final mapped = _messages.indexWhere((m) => m.id == _apiMessages[i].id);
          if (mapped >= 0) out.add(mapped);
        }
      }
    }
    return out.toSet().toList()..sort();
  }

  Future<void> _runServerSearch(String query) async {
    final groupId = widget.groupId;
    if (!_useApi || groupId == null || groupId.isEmpty) return;
    final q = query.trim();
    if (q.length < 2) {
      if (mounted) setState(() => _serverSearchHits = const []);
      return;
    }
    setState(() => _serverSearching = true);
    try {
      final hits = await _groupsRepo.searchChat(groupId, query: q);
      if (!mounted || _searchQuery.trim() != q) return;
      if (hits.isNotEmpty) {
        final existing = _apiMessages.map((m) => m.id).toSet();
        final missing = hits.where((m) => !existing.contains(m.id)).map(_enrichMessageAvatar).toList();
        if (missing.isNotEmpty) {
          _apiMessages = [..._apiMessages, ...missing];
          _messages = _apiMessages.map(_mapApiMessage).toList();
        }
      }
      setState(() {
        _serverSearchHits = hits;
        _serverSearching = false;
        _searchHitIndex = 0;
      });
      _syncSearchIndex();
      final indices = _searchHitIndices;
      if (indices.isNotEmpty) {
        final id = _messages[indices.first].id;
        unawaited(_scrollToMessage(id));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _serverSearching = false);
    }
  }

  void _syncSearchIndex() {
    final hits = _searchHitIndices;
    if (hits.isEmpty) {
      _searchHitIndex = 0;
    } else if (_searchHitIndex >= hits.length) {
      _searchHitIndex = hits.length - 1;
    }
  }

  void _openHeaderTarget() {
    if (widget.viewerMode) {
      showViewerGroupPreviewSheet(
        context,
        groupName: widget.groupName,
        avatarUrl: widget.avatarUrl,
        followers: widget.followers,
        groupId: widget.groupId,
      );
    } else {
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => GroupPreviewScreen(
            groupName: widget.groupName,
            avatarUrl: widget.avatarUrl,
            followers: widget.followers,
            groupId: widget.groupId,
          ),
        ),
      );
    }
  }

  Future<void> _addMember() async {
    final picked = await Navigator.push<(String, String, String)?>(
      context,
      MaterialPageRoute<(String, String, String)?>(builder: (_) => const SelectContactScreen()),
    );
    if (!mounted || picked == null || !_useApi) return;
    try {
      await _groupsRepo.addMember(widget.groupId!, picked.$1);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${picked.$2}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  Future<void> _reactToMessage(GroupThreadMessage msg, String emoji) async {
    if (!_useApi || widget.groupId == null) return;
    try {
      await _groupsRepo.addReaction(widget.groupId!, msg.id, emoji: emoji);
      await _loadApiMessages();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  Future<void> _toggleApiReaction(ChatMessage m, String rawEmoji) async {
    if (!_useApi || widget.groupId == null) return;
    final emoji = sanitizeEmoji(rawEmoji);
    if (emoji == null) return;
    HapticFeedback.selectionClick();
    final existing = m.reactions.where((r) => r.emoji == emoji).toList();
    final mine = existing.isNotEmpty && existing.first.mine;
    try {
      if (mine) {
        await _groupsRepo.removeReaction(widget.groupId!, m.id, emoji: emoji);
      } else {
        await _groupsRepo.addReaction(widget.groupId!, m.id, emoji: emoji);
      }
      await _loadApiMessages();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  Future<void> _showApiMessageActions(ChatMessage m) async {
    final hasText = m.content?.trim().isNotEmpty ?? false;
    final action = await showMessageActionsSheet(
      context,
      canEdit: m.isMine && hasText && !m.hasMedia,
      canDelete: m.isMine,
      canTranslate: hasText,
      canForward: ForwardablePayload.fromMessage(m).canForward,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case MessageAction.reply:
        setState(() {
          _apiReplyTarget = m;
          _replyTarget = null;
        });
        break;
      case MessageAction.forward:
        await _forwardApiMessage(m);
        break;
      case MessageAction.react:
        final emoji = await showEmojiReactionPicker(context);
        if (emoji != null) await _toggleApiReaction(m, emoji);
        break;
      case MessageAction.copy:
        await copyMessageText(context, m.content ?? '');
        break;
      case MessageAction.translate:
        await _translateApiMessage(m);
        break;
      case MessageAction.edit:
        await _editApiMessage(m);
        break;
      case MessageAction.delete:
        await _deleteApiMessage(m);
        break;
    }
  }

  Future<void> _translateApiMessage(ChatMessage m) async {
    if (_translations.containsKey(m.id)) {
      setState(() => _translations.remove(m.id));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Translating…'), duration: Duration(milliseconds: 800)));
    final result = await TranslationService.instance.translate(m.content ?? '');
    if (!mounted) return;
    if (!result.translated) {
      messenger.showSnackBar(const SnackBar(content: Text('Already in your language or unavailable offline.')));
      return;
    }
    setState(() => _translations[m.id] = result.text);
  }

  Future<void> _editApiMessage(ChatMessage m) async {
    if (!_useApi || widget.groupId == null) return;
    final text = await showEditMessageDialog(context, initial: m.content ?? '');
    if (text == null || text.trim().isEmpty || text.trim() == (m.content ?? '').trim()) return;
    if (isChatMessageTooLong(text)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(chatMessageTooLongMessage)));
      return;
    }
    _applyEditedLocally(m.id, text.trim());
    try {
      await _groupsRepo.editMessage(widget.groupId!, m.id, content: text.trim());
      await _loadApiMessages();
    } catch (e) {
      if (!mounted) return;
      await _loadApiMessages();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  void _applyEditedLocally(String messageId, String newContent) {
    if (!mounted) return;
    setState(() {
      _apiMessages = [
        for (final m in _apiMessages)
          if (m.id == messageId)
            m.copyWith(content: newContent, editedAt: DateTime.now())
          else
            m,
      ];
      _translations.remove(messageId);
    });
  }

  Future<void> _deleteApiMessage(ChatMessage m) async {
    if (!_useApi || widget.groupId == null) return;
    final confirm = await confirmDeleteMessage(context);
    if (confirm != true) return;
    _removedMessageIds.add(m.id);
    _removeMessageLocally(m.id);
    try {
      await _groupsRepo.deleteMessage(widget.groupId!, m.id);
    } catch (e) {
      if (!mounted) return;
      _removedMessageIds.remove(m.id);
      await _loadApiMessages();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  void _removeMessageLocally(String messageId) {
    if (!mounted) return;
    setState(() {
      _apiMessages = _apiMessages.where((m) => m.id != messageId).toList();
      _messages = _messages.where((m) => m.id != messageId).toList();
      _translations.remove(messageId);
    });
  }

  Future<void> _sendStickerGroup(String emoji) async {
    if (!_useApi || widget.groupId == null) return;
    final replyId = _apiReplyTarget?.id;
    setState(() => _apiReplyTarget = null);
    try {
      await _groupsRepo.sendGroupMessage(widget.groupId!, content: emoji, replyToMessageId: replyId);
      await _loadApiMessages();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  Future<void> _sendVoiceGroup(String path, int durationSeconds) async {
    if (!_useApi || widget.groupId == null) return;
    final groupId = widget.groupId!;
    final localId = 'vn_${DateTime.now().millisecondsSinceEpoch}';
    final replyId = _apiReplyTarget?.id;
    if (_apiReplyTarget != null) setState(() => _apiReplyTarget = null);
    final pending = ChatPendingUpload(
      localId: localId,
      path: path,
      isVoice: true,
      durationSeconds: durationSeconds,
    );
    setState(() => _pendingUploads.add(pending));
    try {
      final uploaded = await _groupsRepo.uploadMessageFile(
        groupId,
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
        _apiMessages = [..._apiMessages.where((m) => m.id != uploaded.id), uploaded];
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      final i = _pendingUploads.indexWhere((u) => u.localId == localId);
      if (i >= 0) setState(() => _pendingUploads[i].failed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  Future<void> _retryGroupPending(ChatPendingUpload upload) async {
    setState(() => _pendingUploads.removeWhere((u) => u.localId == upload.localId));
    if (upload.isVoice) {
      await _sendVoiceGroup(upload.path, upload.durationSeconds ?? 0);
      return;
    }
    await _startGroupMediaUpload(
      ChatMediaComposeResult(path: upload.path, isVideo: upload.isVideo, caption: upload.caption),
    );
  }

  Future<void> _attachGroup() async {
    if (!_useApi || widget.groupId == null) return;
    FocusScope.of(context).unfocus();
    final choice = await showChatAttachSheet(context);
    if (choice == null || !mounted) return;
    try {
      final pickedList = await pickChatAttachments(context, choice);
      if (pickedList.isEmpty || !mounted) return;
      final docs = pickedList.where((e) => e.isDocument).toList();
      for (final picked in docs) {
        if (!mounted) return;
        await _startGroupDocumentUpload(picked);
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
          await _startGroupMediaUpload(
            ChatMediaComposeResult(path: item.path, isVideo: item.isVideo, caption: item.caption),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  Future<void> _startGroupDocumentUpload(PickedGalleryMedia picked) async {
    final groupId = widget.groupId;
    if (groupId == null) return;
    final localId = 'doc_${DateTime.now().millisecondsSinceEpoch}';
    final replyId = _apiReplyTarget?.id;
    if (_apiReplyTarget != null) setState(() => _apiReplyTarget = null);
    final pending = ChatPendingUpload(
      localId: localId,
      path: picked.file.path,
      isVideo: false,
      isDocument: true,
      caption: picked.file.name,
    );
    setState(() => _pendingUploads.add(pending));
    try {
      final filename = picked.file.name.trim().isEmpty ? 'document.bin' : picked.file.name;
      final uploaded = await _groupsRepo.uploadMessageFile(
        groupId,
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
        _apiMessages = [..._apiMessages.where((m) => m.id != resolved.id), resolved];
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      final i = _pendingUploads.indexWhere((u) => u.localId == localId);
      if (i >= 0) setState(() => _pendingUploads[i].failed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  Future<void> _startGroupMediaUpload(ChatMediaComposeResult composed) async {
    final groupId = widget.groupId;
    if (groupId == null) return;
    final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final replyId = _apiReplyTarget?.id;
    if (_apiReplyTarget != null) setState(() => _apiReplyTarget = null);
    final pending = ChatPendingUpload(
      localId: localId,
      path: composed.path,
      isVideo: composed.isVideo,
      caption: composed.caption,
    );
    setState(() => _pendingUploads.add(pending));
    try {
      final filename = composed.path.split(Platform.pathSeparator).last;
      final uploaded = await _groupsRepo.uploadMessageFile(
        groupId,
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
        _apiMessages = [..._apiMessages.where((m) => m.id != resolved.id), resolved];
      });
    } catch (e) {
      if (!mounted) return;
      final i = _pendingUploads.indexWhere((u) => u.localId == localId);
      if (i >= 0) setState(() => _pendingUploads[i].failed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  void _openSenderProfile(String? userId) {
    if (userId == null || userId.isEmpty) return;
    Navigator.pushNamed(
      context,
      '/profile/other-user',
      arguments: OtherUserProfileArgs(userId: userId),
    );
  }

  GlobalKey _keyForMessage(String id) => _messageKeys.putIfAbsent(id, GlobalKey.new);

  Future<void> _scrollToMessage(String? messageId) async {
    if (messageId == null || messageId.isEmpty) return;
    final exists = _apiMessages.any((m) => m.id == messageId);
    if (!exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Original message is not available')),
      );
      return;
    }
    final rows = coalesceChatImageAlbums(_apiMessages, newestFirst: false);
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

  Widget _buildApiRow(
    ChatAlbumRow row, {
    required bool showSenderName,
    ChatMessage? previous,
    double bottomGap = 8.0,
  }) {
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
    final bubbleText = row.isAlbum ? (row.caption ?? '') : visibleChatCaption(m.content);
    final translated = _translations[m.id];
    final senderLabel = (m.senderName?.trim().isNotEmpty == true) ? m.senderName!.trim() : 'Member';
    final showDate = previous == null || !sameChatCalendarDay(m.createdAt, previous.createdAt);
    final replyTap = m.replyToMessageId == null || m.replyToMessageId!.isEmpty
        ? null
        : () => _scrollToMessage(m.replyToMessageId);
    final highlight = _highlightMessageId != null && row.messageIds.contains(_highlightMessageId!);
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
          onLongPress: () => _showApiMessageActions(m),
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
                  onReactionTap: (e) => _toggleApiReaction(m, e),
                  edited: m.isEdited,
                  replySnippet: m.replySnippet,
                  onReplyTap: replyTap,
                )
              : ReceivedMessageBubble(
                  text: bubbleText,
                  timeLabel: m.timeLabel,
                  avatarUrl: m.senderAvatarUrl ?? '',
                  senderName: showSenderName ? senderLabel : null,
                  senderColor: _senderColorFor(m.senderId, m.senderName),
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
                  onReactionTap: (e) => _toggleApiReaction(m, e),
                  onAvatarTap: () => _openSenderProfile(m.senderId),
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
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (_searchOpen) {
        _searchQuery = '';
        _searchField.clear();
      } else {
        _searchQuery = '';
      }
      _syncSearchIndex();
    });
  }

  void _send() {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    if (_useApi) {
      final replyId = _apiReplyTarget?.id;
      _input.clear();
      setState(() => _apiReplyTarget = null);
      _sendApiMessage(t, replyToMessageId: replyId);
      return;
    }
    final snippet = _replyTarget != null ? _snippetForReply(_replyTarget!) : null;
    final shortSnippet = snippet == null ? null : truncateSafely(snippet, 48);
    setState(() {
      _messages.add(
        GroupThreadMessage.outgoing(
          id: 'local_${DateTime.now().microsecondsSinceEpoch}',
          text: t,
          time: _formatTime(),
          replySnippet: shortSnippet,
        ),
      );
      _input.clear();
      _replyTarget = null;
    });
    _scrollToBottom();
  }

  Future<void> _showOutgoingSheet(GroupThreadMessage msg) async {
    const barrier = Color(0xCC0A0A0A);
    const cardBg = Color(0xFFF6F6F6);
    const hairline = Color(0x1A0A0A0A);
    const destructive = Color(0xFFEF003B);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: barrier,
      transitionDuration: Duration.zero,
      pageBuilder: (ctx, _, _) {
        final h = MediaQuery.sizeOf(ctx).height;
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: h * 0.33,
              right: 16,
              width: 220,
              child: Material(
                color: cardBg,
                elevation: 0,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: hairline),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ContextMenuRow(
                        icon: Icons.sentiment_satisfied_alt_rounded,
                        label: 'React',
                        onTap: () async {
                          Navigator.pop(ctx);
                          final e = await showEmojiReactionPicker(context);
                          if (!mounted || e == null) return;
                          if (_useApi) {
                            await _reactToMessage(msg, e);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reacted $e')));
                          }
                        },
                      ),
                      Divider(height: 1, thickness: 1, color: hairline),
                      _ContextMenuRow(
                        icon: Icons.reply_rounded,
                        label: 'Reply',
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _replyTarget = msg;
                            _apiReplyTarget = null;
                          });
                        },
                      ),
                      Divider(height: 1, thickness: 1, color: hairline),
                      _ContextMenuRow(
                        icon: Icons.shortcut_rounded,
                        label: 'Forward',
                        onTap: () {
                          Navigator.pop(ctx);
                          _forwardDemoMessage(msg);
                        },
                      ),
                      Divider(height: 1, thickness: 1, color: hairline),
                      _ContextMenuRow(
                        icon: Icons.copy_rounded,
                        label: 'Copy Message',
                        onTap: () {
                          Navigator.pop(ctx);
                          final text = msg.bodyText ?? '';
                          Clipboard.setData(ClipboardData(text: text));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
                        },
                      ),
                      Divider(height: 1, thickness: 1, color: hairline),
                      _ContextMenuRow(
                        icon: Icons.edit_outlined,
                        label: 'Edit Message',
                        onTap: () async {
                          Navigator.pop(ctx);
                          final next = await showEditMessageSheet(
                            context,
                            initialText: msg.bodyText ?? '',
                            hintText: 'Edit text already sent',
                          );
                          if (!mounted || next == null || next.isEmpty) return;
                          final idx = _messages.indexWhere((m) => m.id == msg.id);
                          if (idx >= 0) {
                            setState(() {
                              _messages[idx] = GroupThreadMessage.outgoing(
                                id: msg.id,
                                text: next,
                                time: msg.time,
                                replySnippet: msg.replySnippet,
                              );
                            });
                          }
                        },
                      ),
                      Divider(height: 1, thickness: 1, color: hairline),
                      _ContextMenuRow(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete Message',
                        foreground: destructive,
                        onTap: () async {
                          Navigator.pop(ctx);
                          final del = await showDeleteMessageDialog(context);
                          if (del == true && mounted) {
                            setState(() => _messages.removeWhere((m) => m.id == msg.id));
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessageRow(GroupThreadMessage m, {GroupThreadMessage? previous, GroupThreadMessage? next}) {
    final showName = m.kind == GroupThreadRowKind.incomingText || m.kind == GroupThreadRowKind.incomingImage
        ? (m.senderName?.trim().isNotEmpty == true) &&
            (previous == null ||
                previous.kind == GroupThreadRowKind.outgoingText ||
                previous.kind == GroupThreadRowKind.system ||
                previous.senderId != m.senderId ||
                previous.senderName != m.senderName)
        : false;
    final sameSenderAsNext = next != null &&
        (m.senderId != null && next.senderId != null
            ? m.senderId == next.senderId
            : m.kind == next.kind);
    final bottomGap = m.kind == GroupThreadRowKind.system ? 8.0 : (next == null ? 12.0 : (sameSenderAsNext ? 2.0 : 8.0));
    final nameColor = _senderColorFor(m.senderId, m.senderName);
    switch (m.kind) {
      case GroupThreadRowKind.system:
        return Padding(
          padding: EdgeInsets.only(bottom: bottomGap),
          child: GroupSystemEvent(text: m.systemText ?? ''),
        );
      case GroupThreadRowKind.outgoingText:
        return Padding(
          padding: EdgeInsets.only(bottom: bottomGap),
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onLongPress: () => _showOutgoingSheet(m),
              child: OutgoingThreadBubble(text: m.bodyText ?? '', timeLabel: m.time, replySnippet: m.replySnippet),
            ),
          ),
        );
      case GroupThreadRowKind.incomingText:
        return Padding(
          padding: EdgeInsets.only(bottom: bottomGap),
          child: Align(
            alignment: Alignment.centerLeft,
            child: IncomingThreadTextBubble(
              text: m.bodyText ?? '',
              time: m.time,
              avatarUrl: m.avatarUrl ?? '',
              senderName: showName ? (m.senderName ?? 'Member') : null,
              senderColor: nameColor,
              replySnippet: m.replySnippet,
            ),
          ),
        );
      case GroupThreadRowKind.incomingImage:
        return Padding(
          padding: EdgeInsets.only(bottom: bottomGap),
          child: Align(
            alignment: Alignment.centerLeft,
            child: IncomingImageThreadBubble(
              imageUrl: m.imageUrl ?? '',
              time: m.time,
              avatarUrl: m.avatarUrl ?? '',
              senderName: showName ? (m.senderName ?? 'Member') : null,
              senderColor: nameColor,
              reactions: m.reactions,
              caption: m.bodyText,
              replySnippet: m.replySnippet,
              onReactionTap: () => showReactionsDetailSheet(context),
            ),
          ),
        );
    }
  }

  PreferredSizeWidget? _appBarBottom() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: Colors.grey.shade200),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hits = _searchHitIndices;
    if (_searchOpen) {
      _syncSearchIndex();
    }

    return Scaffold(
      backgroundColor: ChatTheme.chatBgAlt,
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
                  setState(() {
                    _searchQuery = v;
                    _searchHitIndex = 0;
                  });
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(const Duration(milliseconds: 320), () {
                    unawaited(_runServerSearch(v));
                  });
                },
                decoration: InputDecoration(
                  hintText: _serverSearching ? 'Searching…' : 'Search',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _toggleSearch,
                ),
              ],
              bottom: _appBarBottom(),
            )
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              foregroundColor: ChatTheme.black,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => Navigator.pop(context)),
              titleSpacing: 0,
              title: GestureDetector(
                onTap: _openHeaderTarget,
                child: Row(
                  children: [
                    UserAvatar(radius: 18, imageUrl: widget.avatarUrl.isEmpty ? null : widget.avatarUrl),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.groupName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          Text('${widget.followers} followers', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (_useApi)
                  ...groupChatCallActions(
                    context: context,
                    groupId: widget.groupId!,
                    groupName: widget.groupName,
                  ),
                if (!widget.viewerMode)
                  IconButton(
                    icon: const Icon(Icons.person_add_outlined),
                    onPressed: _addMember,
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: ChatTheme.black),
                  onSelected: (v) async {
                    if (v == 'members' && widget.groupId != null) {
                      await Navigator.pushNamed(
                        context,
                        '/groups/members',
                        arguments: GroupMembersArgs(groupId: widget.groupId!, groupName: widget.groupName),
                      );
                    } else if (v == 'profile' && !widget.viewerMode) {
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => GroupPreviewScreen(
                            groupName: widget.groupName,
                            avatarUrl: widget.avatarUrl,
                            followers: widget.followers,
                            groupId: widget.groupId,
                          ),
                        ),
                      );
                    } else if (v == 'search') {
                      _toggleSearch();
                    } else if (v == 'media') {
                      await openGroupMediaGallery(
                        context,
                        groupName: widget.groupName,
                        messages: _apiMessages,
                      );
                    } else if (v == 'leave') {
                      final ok = await showLeaveGroupDialog(context, groupName: widget.groupName);
                      if (ok != true || !context.mounted) return;
                      if (_useApi && widget.groupId != null) {
                        try {
                          await _groupsRepo.leaveGroup(widget.groupId!);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(friendlyApiMessage(e))),
                            );
                          }
                          return;
                        }
                      }
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  itemBuilder: (_) => [
                    if (_useApi)
                      const PopupMenuItem(value: 'members', child: Text('Members')),
                    if (!widget.viewerMode)
                      const PopupMenuItem(value: 'profile', child: Text('Group profile')),
                    const PopupMenuItem(value: 'search', child: Text('Search')),
                    if (_useApi)
                      const PopupMenuItem(value: 'media', child: Text('Media')),
                    const PopupMenuItem(value: 'leave', child: Text('Leave group')),
                  ],
                ),
              ],
              bottom: _appBarBottom(),
            ),
      body: Column(
        children: [
          const ConnectionStatusPill(darkBackground: false),
          Expanded(
            child: _loadingMessages && !_messagesReady
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: ChatTheme.purple))
                : _showJoinEmptyState
                    ? _GroupChatEmptyState(
                        groupName: widget.groupName,
                        historyHidden: _historyHidden,
                      )
                    : Builder(builder: (context) {
              final apiRows = _useApi ? coalesceChatImageAlbums(_apiMessages, newestFirst: false) : const <ChatAlbumRow>[];
              return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: (widget.showWelcome ? 1 : 0) +
                  (_useApi ? apiRows.length + _pendingUploads.length : _messages.length),
              itemBuilder: (_, i) {
                if (widget.showWelcome && i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GroupWelcomeHeader(groupName: widget.groupName, avatarUrl: widget.avatarUrl),
                  );
                }
                final mi = widget.showWelcome ? i - 1 : i;
                if (_useApi) {
                  if (mi < apiRows.length) {
                    final row = apiRows[mi];
                    final prev = mi > 0 ? apiRows[mi - 1].message : null;
                    final next = mi + 1 < apiRows.length ? apiRows[mi + 1].message : null;
                    final bool nextIsSameSender;
                    if (next != null) {
                      final same = (row.message.senderId == next.senderId && row.message.isMine == next.isMine);
                      final hasDate = !sameChatCalendarDay(next.createdAt, row.message.createdAt);
                      nextIsSameSender = same && !hasDate;
                    } else if (_pendingUploads.isNotEmpty) {
                      nextIsSameSender = row.message.isMine;
                    } else {
                      nextIsSameSender = false;
                    }
                    final bottomGap = nextIsSameSender ? 2.0 : (next == null && _pendingUploads.isEmpty ? 12.0 : 8.0);
                    return _buildApiRow(
                      row,
                      showSenderName: _shouldShowSenderName(row.message, prev),
                      previous: prev,
                      bottomGap: bottomGap,
                    );
                  }
                  final pendingIndex = mi - apiRows.length;
                  final pending = _pendingUploads[pendingIndex];
                  final pendingBottom = (pendingIndex + 1 < _pendingUploads.length) ? 2.0 : 12.0;
                  return Padding(
                    padding: EdgeInsets.only(bottom: pendingBottom),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: PendingMediaBubble(
                        upload: pending,
                        onRetry: pending.failed ? () => _retryGroupPending(pending) : null,
                      ),
                    ),
                  );
                }
                return _buildMessageRow(
                  _messages[mi],
                  previous: mi > 0 ? _messages[mi - 1] : null,
                  next: mi + 1 < _messages.length ? _messages[mi + 1] : null,
                );
              },
            );
            }),
          ),
          if (_searchOpen && hits.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  Text('${_searchHitIndex + 1} of ${hits.length}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.keyboard_arrow_up_rounded, color: Colors.grey.shade800),
                    onPressed: () {
                      setState(() {
                        if (hits.isEmpty) return;
                        _searchHitIndex = (_searchHitIndex - 1 + hits.length) % hits.length;
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade800),
                    onPressed: () {
                      setState(() {
                        if (hits.isEmpty) return;
                        _searchHitIndex = (_searchHitIndex + 1) % hits.length;
                      });
                    },
                  ),
                ],
              ),
            ),
          if (_groupCallInvite != null)
            _GroupCallInviteBanner(
              callType: _groupCallInvite!.callType,
              onJoin: _joinActiveGroupCall,
              onDismiss: _dismissGroupCallInvite,
            ),
          ChatComposerBar(
            controller: _input,
            onSend: _send,
            hintText: 'Say something...',
            replyingLabel: _apiReplyTarget != null
                ? 'Replying to: ${_snippetForApiReply(_apiReplyTarget!)}'
                : _replyTarget != null
                    ? 'Replying to: ${_snippetForReply(_replyTarget!)}'
                    : null,
            onCancelReply: (_apiReplyTarget != null || _replyTarget != null)
                ? () => setState(() {
                      _apiReplyTarget = null;
                      _replyTarget = null;
                    })
                : null,
            onAttach: _useApi ? _attachGroup : null,
            onSendSticker: _useApi ? _sendStickerGroup : null,
            onSendVoice: _useApi ? _sendVoiceGroup : null,
          ),
        ],
      ),
    );
  }
}

class _GroupCallInviteBanner extends StatelessWidget {
  const _GroupCallInviteBanner({
    required this.callType,
    required this.onJoin,
    required this.onDismiss,
  });

  final CallMediaType callType;
  final VoidCallback onJoin;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final label = callType == CallMediaType.video ? 'Group video call in progress' : 'Group call in progress';
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF8A2DDC),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Icon(callType == CallMediaType.video ? Icons.videocam_rounded : Icons.call_rounded, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          ),
          TextButton(
            onPressed: onDismiss,
            child: const Text('Dismiss', style: TextStyle(color: Colors.white70)),
          ),
          const SizedBox(width: 4),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF8A2DDC)),
            onPressed: onJoin,
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}

class _GroupChatEmptyState extends StatelessWidget {
  const _GroupChatEmptyState({
    required this.groupName,
    required this.historyHidden,
  });

  final String groupName;
  final bool historyHidden;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                historyHidden ? Icons.lock_outline_rounded : Icons.chat_bubble_outline_rounded,
                size: 36,
                color: ChatTheme.grey,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              historyHidden ? 'You\'re all caught up' : 'No messages yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ChatTheme.black,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              historyHidden
                  ? 'Messages from before you joined $groupName aren\'t shown here. Say hello to start chatting.'
                  : 'Send a message to start the conversation in $groupName.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: ChatTheme.greyLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextMenuRow extends StatelessWidget {
  const _ContextMenuRow({required this.icon, required this.label, required this.onTap, this.foreground = ChatTheme.black});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: foreground, height: 20 / 14)),
            ),
          ],
        ),
      ),
    );
  }
}
