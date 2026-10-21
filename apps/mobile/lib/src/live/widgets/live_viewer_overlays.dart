import 'package:flutter/material.dart';

import '../../../core/widgets/user_avatar.dart';
import '../live_theme.dart';

class LiveHostBar extends StatelessWidget {
  const LiveHostBar({
    super.key,
    required this.hostName,
    this.hostAvatarUrl,
    required this.viewerCount,
    this.elapsedLabel,
  });

  final String hostName;
  final String? hostAvatarUrl;
  final int viewerCount;
  final String? elapsedLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: LiveTheme.overlay,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: LiveTheme.pillBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          UserAvatar(radius: 16, imageUrl: hostAvatarUrl),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.28),
            child: Text(
              hostName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(999)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text('LIVE', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                const SizedBox(width: 6),
                Icon(Icons.remove_red_eye_rounded, size: 12, color: Colors.white.withValues(alpha: 0.95)),
                const SizedBox(width: 3),
                Text('$viewerCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
              ],
            ),
          ),
          if (elapsedLabel != null && elapsedLabel!.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Text(
                elapsedLabel!,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11, fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class LiveViewerChip {
  const LiveViewerChip({required this.id, required this.name, this.avatarUrl});

  final String id;
  final String name;
  final String? avatarUrl;
}

class LiveHostViewerChip extends StatelessWidget {
  const LiveHostViewerChip({
    super.key,
    required this.viewers,
    required this.totalCount,
    required this.onTap,
  });

  final List<LiveViewerChip> viewers;
  final int totalCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = viewers.take(3).toList();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: LiveTheme.pillFill,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: LiveTheme.pillBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (preview.isNotEmpty) ...[
                SizedBox(
                  height: 22,
                  width: preview.length == 1 ? 22 : (22 + (preview.length - 1) * 12.0),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var i = 0; i < preview.length; i++)
                        Positioned(
                          left: i * 12.0,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black54, width: 1.5),
                            ),
                            child: UserAvatar(
                              radius: 10,
                              imageUrl: preview[i].avatarUrl,
                              backgroundColor: Colors.grey.shade800,
                              iconColor: Colors.white70,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
              ],
              const Icon(Icons.visibility_rounded, size: 15, color: Colors.white70),
              const SizedBox(width: 4),
              Text(
                '$totalCount',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LiveViewerPopover extends StatelessWidget {
  const LiveViewerPopover({
    super.key,
    required this.viewers,
    required this.totalCount,
    required this.onSeeAll,
  });

  final List<LiveViewerChip> viewers;
  final int totalCount;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return LiveHostViewerChip(viewers: viewers, totalCount: totalCount, onTap: onSeeAll);
  }
}

class LiveStreamViewerRow {
  const LiveStreamViewerRow({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.muted = false,
    this.talkBack = false,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final bool muted;
  final bool talkBack;
}

Future<void> showLiveManageViewersSheet(
  BuildContext context, {
  required List<LiveStreamViewerRow> viewers,
  required Future<void> Function(LiveStreamViewerRow viewer) onToggleMute,
  required Future<void> Function(LiveStreamViewerRow viewer) onToggleTalkBack,
  required Future<void> Function(String userId) onRemove,
  bool talkBackControls = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (_, scroll) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(100))),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Manage viewers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                Expanded(
                  child: viewers.isEmpty
                      ? Center(child: Text('No viewers yet', style: TextStyle(color: Colors.grey.shade600)))
                      : ListView.separated(
                          controller: scroll,
                          itemCount: viewers.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                          itemBuilder: (_, i) {
                            final v = viewers[i];
                            return ListTile(
                              leading: UserAvatar(radius: 22, imageUrl: v.avatarUrl),
                              title: Text(v.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: v.muted || v.talkBack
                                  ? Text([if (v.muted) 'Muted', if (v.talkBack) 'Talk-back'].join(' · '), style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (talkBackControls) ...[
                                    IconButton(
                                      onPressed: v.talkBack ? () => onToggleMute(v) : null,
                                      icon: Icon(v.muted ? Icons.mic_off_rounded : Icons.mic_rounded, color: v.talkBack ? LiveTheme.purple : Colors.grey.shade400),
                                    ),
                                    IconButton(
                                      onPressed: () => onToggleTalkBack(v),
                                      icon: Icon(v.talkBack ? Icons.record_voice_over_rounded : Icons.voice_over_off_outlined, color: LiveTheme.purple),
                                    ),
                                  ],
                                  IconButton(
                                    onPressed: () => onRemove(v.id),
                                    icon: const Icon(Icons.person_remove_outlined),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
