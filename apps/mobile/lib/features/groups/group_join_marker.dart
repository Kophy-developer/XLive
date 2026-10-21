import '../chats/models/chat_api_models.dart';
import '../../core/session/auth_session.dart';

abstract final class GroupJoinMarker {
  static const _wrap = '\u2063';
  static const _tag = 'xlj';

  static String contentFor(String userId) => '$_wrap$_tag:$userId$_wrap';

  static String? get myContent {
    final id = AuthSession.instance.user?.id;
    if (id == null || id.isEmpty) return null;
    return contentFor(id);
  }

  static String? get searchQuery => myContent;

  static bool isMarker(ChatMessage message) {
    final text = message.content ?? '';
    return text.contains('$_wrap$_tag:');
  }

  static bool isMyMarker(ChatMessage message) {
    final mine = myContent;
    if (mine == null) return false;
    return (message.content ?? '') == mine;
  }
}
