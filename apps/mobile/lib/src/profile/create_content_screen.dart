import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/network/api_friendly_messages.dart';
import '../../core/session/auth_session.dart';
import '../../features/clips/clips_repository.dart';
import '../../features/feed/feed_album.dart';
import '../../features/videos/videos_repository.dart';
import '../media/media_editor_screen.dart';
import '../media/media_picker_utils.dart';
import '../media/video_duration.dart';
import '../../core/feed/home_feed_refresh.dart';
import 'creator_tools_screens.dart';

const _black = Color(0xFF0A0A0A);
const _grey = Color(0xFF8E8E93);
const _fieldBg = Color(0xFFF4F4F6);
const _purpleA = Color(0xFF8A3FFC);
const _pink = Color(0xFFEC4899);

LinearGradient get _brandGradient => const LinearGradient(colors: [_purpleA, _pink]);

void _showPublishErrorToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: _black,
      elevation: 4,
      margin: EdgeInsets.only(left: 24, right: 24, bottom: MediaQuery.paddingOf(context).bottom + 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
  );
}

class CreateContentScreen extends StatefulWidget {
  const CreateContentScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<CreateContentScreen> createState() => _CreateContentScreenState();
}

class _CreateContentScreenState extends State<CreateContentScreen> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text('Create content', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _black)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: _fieldBg, borderRadius: BorderRadius.circular(999)),
              child: Row(
                children: [
                  _segTab('Post', 0),
                  _segTab('Collectible clip', 1),
                ],
              ),
            ),
          ),
          Expanded(
            child: _tab == 0
                ? const _PostForm()
                : const CreatorGate(embedded: true, child: _CollectibleForm()),
          ),
        ],
      ),
    );
  }

  Widget _segTab(String label, int i) {
    final on = _tab == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            gradient: on ? _brandGradient : null,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: on ? Colors.white : _grey,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PostForm extends StatefulWidget {
  const _PostForm();

  @override
  State<_PostForm> createState() => _PostFormState();
}

class _PostFormState extends State<_PostForm> {
  final _videosRepo = VideosRepository();
  final _caption = TextEditingController();
  final _unlockPrice = TextEditingController();

  static const _visibilityOptions = ['Everyone', 'Followers', 'Subscribers'];
  static const _categoryOptions = ['Music', 'Comedy', 'Education', 'Gaming', 'Lifestyle', 'Sports', 'News', 'Other'];
  static const _visibilityApi = {
    'Everyone': 'everyone',
    'Followers': 'followers',
    'Subscribers': 'subscribers',
  };
  static const _categoryApi = {
    'Music': 'music',
    'Comedy': 'comedy',
    'Education': 'education',
    'Gaming': 'gaming',
    'Lifestyle': 'lifestyle',
    'Sports': 'sports',
    'News': 'news',
    'Other': 'other',
  };

  String _visibility = 'Everyone';
  String _category = 'Music';
  bool _confirmCopyright = true;
  final List<PickedGalleryMedia> _mediaItems = [];
  bool _publishing = false;

  @override
  void dispose() {
    _caption.dispose();
    _unlockPrice.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_mediaItems.isEmpty) {
      _toast('Add a photo or video first');
      return;
    }
    final hasVideo = _mediaItems.any((m) => m.isVideo);
    if (hasVideo && !_confirmCopyright) {
      _toast('Please confirm sound copyright');
      return;
    }
    setState(() => _publishing = true);
    try {
      final price = int.tryParse(_unlockPrice.text.trim());
      final caption = _caption.text.trim().isEmpty ? null : _caption.text.trim();
      final albumId = _mediaItems.length > 1 ? newFeedAlbumId() : null;
      final visibility = _visibilityApi[_visibility] ?? 'everyone';
      final category = _categoryApi[_category] ?? 'other';
      for (var i = 0; i < _mediaItems.length; i++) {
        final media = _mediaItems[i];
        String? itemCaption;
        if (albumId != null) {
          itemCaption = wrapFeedAlbumCaption(caption, albumId);
        } else {
          itemCaption = caption;
        }
        String filename;
        if (media.isVideo) {
          filename = uploadFilenameFor(media);
        } else {
          final bytes = await File(media.file.path).readAsBytes();
          filename = uploadFilenameForImageBytes(media, bytes);
        }
        final fields = <String, String>{
          'type': 'post',
          'visibility': visibility,
          'category': category,
          'soundCopyrightChecked': 'true',
          'mediaType': media.isVideo ? 'video' : 'image',
        };
        if (media.isVideo) {
          final duration = await readVideoDurationSeconds(media.file.path);
          fields['duration'] = '$duration';
        }
        await _videosRepo.uploadVideoFile(
          media.file.path,
          filename: filename,
          caption: itemCaption ?? caption,
          unlockPrice: price,
          fields: fields,
        );
      }
      if (!mounted) return;
      _toast(_mediaItems.length > 1 ? 'Posts published' : 'Post published');
      HomeFeedRefresh.instance.request();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showPublishErrorToast(context, friendlyApiMessage(e, fallback: 'Could not publish post.'));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + MediaQuery.paddingOf(context).bottom),
      children: [
        _label('PHOTO OR VIDEO'),
        _MediaUploadPicker(
          mediaItems: _mediaItems,
          kind: GalleryMediaKind.imageOrVideo,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 20),
        _label('CAPTION'),
        _input(_caption, 'Caption...', maxLines: 3),
        const SizedBox(height: 20),
        _label('VISIBILITY'),
        _dropdown(_visibility, _visibilityOptions, (v) => setState(() => _visibility = v)),
        const SizedBox(height: 20),
        _label('UNLOCK PRICE (COINS)'),
        _input(_unlockPrice, 'e.g. 100', keyboardType: TextInputType.number, suffixText: 'coins'),
        const SizedBox(height: 20),
        _label('CATEGORY'),
        _dropdown(_category, _categoryOptions, (v) => setState(() => _category = v)),
        if (_mediaItems.any((m) => m.isVideo)) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _confirmCopyright,
                onChanged: (v) => setState(() => _confirmCopyright = v ?? false),
                activeColor: _purpleA,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              const Expanded(
                child: Text('I confirm sound copyright', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _black)),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        _PublishBar(busy: _publishing, onCancel: () => Navigator.pop(context), onPublish: _publish),
      ],
    );
  }
}

class _CollectibleForm extends StatefulWidget {
  const _CollectibleForm();

  @override
  State<_CollectibleForm> createState() => _CollectibleFormState();
}

class _CollectibleFormState extends State<_CollectibleForm> {
  final _clipsRepo = ClipsRepository();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController(text: '5');
  final _supply = TextEditingController(text: '10');

  final List<PickedGalleryMedia> _mediaItems = [];
  bool _publishing = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _supply.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final session = AuthSession.instance;
    if (!session.isCreator && !session.creatorMode) {
      _toast('Creator mode required to mint collectible clips');
      return;
    }
    if (_mediaItems.isEmpty) {
      _toast('Add an image or short video first');
      return;
    }
    if (_name.text.trim().isEmpty) {
      _toast('Add a clip name');
      return;
    }
    final price = int.tryParse(_price.text.trim()) ?? 0;
    if (price < 1) {
      _toast('Set a price of at least 1 coin');
      return;
    }
    final supply = int.tryParse(_supply.text.trim()) ?? 0;
    if (supply < 1) {
      _toast('Editions must be at least 1');
      return;
    }
    setState(() => _publishing = true);
    try {
      String? lastId;
      for (var i = 0; i < _mediaItems.length; i++) {
        final media = _mediaItems[i];
        final created = await _clipsRepo.createCollectible(
          filePath: media.file.path,
          filename: uploadFilenameFor(media),
          name: i == 0 ? _name.text.trim() : '${_name.text.trim()} (${i + 1})',
          description: _description.text.trim().isEmpty ? null : _description.text.trim(),
          price: price,
          maxSupply: supply,
        );
        lastId = created.id;
      }
      if (!mounted) return;
      _toast(_mediaItems.length > 1 ? 'Collectibles published' : 'Collectible published');
      if (lastId == null || lastId.isEmpty) {
        Navigator.pushReplacementNamed(context, '/profile/creator/created-clips');
      } else {
        Navigator.pushReplacementNamed(
          context,
          '/profile/creator/created-clips/detail',
          arguments: lastId,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showPublishErrorToast(context, friendlyApiMessage(e, fallback: 'Could not publish collectible.'));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + MediaQuery.paddingOf(context).bottom),
      children: [
        _label('IMAGE OR SHORT VIDEO'),
        _MediaUploadPicker(
          mediaItems: _mediaItems,
          kind: GalleryMediaKind.imageOrVideo,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 20),
        _label('NAME'),
        _input(_name, 'Clip name...'),
        const SizedBox(height: 20),
        _label('DESCRIPTION'),
        _input(_description, 'Description...', maxLines: 3),
        const SizedBox(height: 20),
        _label('PRICE (COINS)'),
        _input(_price, 'e.g. 5', keyboardType: TextInputType.number, suffixText: 'coins'),
        const SizedBox(height: 20),
        _label('EDITIONS'),
        _input(_supply, 'e.g. 10', keyboardType: TextInputType.number, suffixText: 'max'),
        const SizedBox(height: 8),
        Text(
          'Buyers purchase editions. You can archive after sales start.',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, height: 1.35),
        ),
        const SizedBox(height: 24),
        _PublishBar(busy: _publishing, onCancel: () => Navigator.pop(context), onPublish: _publish),
      ],
    );
  }
}

Widget _label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _grey, letterSpacing: 0.4)),
    );

Widget _input(TextEditingController c, String hint, {int maxLines = 1, TextInputType? keyboardType, String? suffixText}) {
  return TextField(
    controller: c,
    maxLines: maxLines,
    keyboardType: keyboardType,
    style: const TextStyle(fontSize: 15, color: _black),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _grey),
      suffixText: suffixText,
      suffixStyle: const TextStyle(color: _grey, fontWeight: FontWeight.w600),
      filled: true,
      fillColor: _fieldBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
  );
}

Widget _dropdown(String value, List<String> options, ValueChanged<String> onChanged) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(color: _fieldBg, borderRadius: BorderRadius.circular(12)),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        borderRadius: BorderRadius.circular(12),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _grey),
        style: const TextStyle(fontSize: 15, color: _black),
        items: options.map((o) => DropdownMenuItem<String>(value: o, child: Text(o))).toList(),
        onChanged: (v) => v == null ? null : onChanged(v),
      ),
    ),
  );
}

class _MediaUploadPicker extends StatefulWidget {
  const _MediaUploadPicker({
    required this.mediaItems,
    required this.kind,
    required this.onChanged,
  });

  final List<PickedGalleryMedia> mediaItems;
  final GalleryMediaKind kind;
  final VoidCallback onChanged;

  @override
  State<_MediaUploadPicker> createState() => _MediaUploadPickerState();
}

class _MediaUploadPickerState extends State<_MediaUploadPicker> {
  final Map<String, String> _thumbs = {};

  Future<void> _pick() async {
    final picked = await pickGalleryMediaMulti(context, kind: widget.kind, allowMultiple: true);
    if (picked.isEmpty || !mounted) return;
    for (final item in picked) {
      if (!mounted) return;
      if (item.isVideo) {
        final edited = await openMediaEditor(context, item);
        if (!mounted) return;
        final next = edited?.toPickedMedia() ?? item;
        widget.mediaItems.add(next);
        widget.onChanged();
        unawaited(_ensureThumb(next));
      } else {
        widget.mediaItems.add(item);
        widget.onChanged();
      }
    }
  }

  Future<void> _ensureThumb(PickedGalleryMedia media) async {
    if (!media.isVideo) return;
    final path = media.file.path;
    if (_thumbs.containsKey(path)) return;
    final thumb = await videoThumbnailPath(path);
    if (!mounted || thumb == null) return;
    setState(() => _thumbs[path] = thumb);
  }

  Future<void> _editAt(int index) async {
    final media = widget.mediaItems[index];
    final edited = await openMediaEditor(context, media);
    if (edited == null || !mounted) return;
    widget.mediaItems[index] = edited.toPickedMedia();
    widget.onChanged();
  }

  void _removeAt(int index) {
    widget.mediaItems.removeAt(index);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaItems.isEmpty) {
      return InkWell(
        onTap: _pick,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          height: 180,
          decoration: BoxDecoration(
            color: _fieldBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: _brandGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 14),
              const Text('Add photos or videos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _black)),
              const SizedBox(height: 4),
              Text('Select multiple from library or camera', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.mediaItems.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index == widget.mediaItems.length) {
                return InkWell(
                  onTap: _pick,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 120,
                    decoration: BoxDecoration(
                      color: _fieldBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, size: 28, color: _black),
                        SizedBox(height: 6),
                        Text('Add more', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                  ),
                );
              }
              final media = widget.mediaItems[index];
              final thumb = _thumbs[media.file.path];
              if (media.isVideo && thumb == null) unawaited(_ensureThumb(media));
              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 140,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (!media.isVideo)
                        Image.file(File(media.file.path), fit: BoxFit.cover)
                      else if (thumb != null)
                        Image.file(File(thumb), fit: BoxFit.cover)
                      else
                        Container(color: _fieldBg, child: const Center(child: Icon(Icons.videocam_rounded))),
                      if (media.isVideo)
                        const Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 28),
                          ),
                        ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          children: [
                            if (!media.isVideo)
                              _chipAction(Icons.tune_rounded, () => _editAt(index)),
                            const SizedBox(width: 6),
                            _chipAction(Icons.close_rounded, () => _removeAt(index)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _chipAction(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      ),
    );
  }
}

class _PublishBar extends StatelessWidget {
  const _PublishBar({required this.busy, required this.onCancel, required this.onPublish});

  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: busy ? null : onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: _black,
              side: BorderSide(color: Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: _brandGradient, borderRadius: BorderRadius.circular(14)),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: busy ? null : onPublish,
                  borderRadius: BorderRadius.circular(14),
                  child: Center(
                    child: busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Publish', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
