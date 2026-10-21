import 'package:flutter/material.dart';

import '../../core/media/media_url.dart';
import '../../features/chats/models/chat_api_models.dart';
import 'chat_media_viewer.dart';
import 'chat_theme.dart';

Future<void> openGroupMediaGallery(
  BuildContext context, {
  required String groupName,
  required List<ChatMessage> messages,
}) {
  return Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => GroupMediaGalleryScreen(groupName: groupName, messages: messages),
    ),
  );
}

class GroupMediaGalleryScreen extends StatelessWidget {
  const GroupMediaGalleryScreen({
    super.key,
    required this.groupName,
    required this.messages,
  });

  final String groupName;
  final List<ChatMessage> messages;

  List<ChatMessage> get _media {
    final out = messages.where((m) => m.hasMedia && (m.isImage || m.isVideo)).toList();
    out.sort((a, b) {
      final aa = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bb.compareTo(aa);
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final items = _media;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: ChatTheme.black,
        surfaceTintColor: Colors.transparent,
        title: Text('Media · $groupName', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: items.isEmpty
          ? Center(
              child: Text('No photos or videos yet', style: TextStyle(color: Colors.grey.shade600)),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 3,
                mainAxisSpacing: 3,
              ),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final m = items[i];
                final thumb = resolveMediaUrl(m.mediaUrl, resourceType: 'image');
                return GestureDetector(
                  onTap: () {
                    if (m.isVideo) {
                      openChatVideoViewer(context, m.mediaUrl ?? '');
                    } else {
                      openChatImageViewer(context, thumb);
                    }
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (m.isImage)
                        Image.network(
                          thumb,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        )
                      else
                        ColoredBox(
                          color: Colors.black87,
                          child: Image.network(
                            thumb,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(Icons.videocam_rounded, color: Colors.white54, size: 36),
                            ),
                          ),
                        ),
                      if (m.isVideo)
                        const Align(
                          alignment: Alignment.center,
                          child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 36),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
