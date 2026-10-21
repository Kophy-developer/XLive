import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../media/media_picker_utils.dart';
import 'chat_theme.dart';

enum ChatAttachChoice { gallery, camera, document }

Future<ChatAttachChoice?> showChatAttachSheet(BuildContext context) {
  return showModalBottomSheet<ChatAttachChoice>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: ChatTheme.purple),
            title: const Text('Gallery'),
            subtitle: const Text('Photos or videos'),
            onTap: () => Navigator.pop(context, ChatAttachChoice.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded, color: ChatTheme.purple),
            title: const Text('Camera'),
            subtitle: const Text('Photo or video'),
            onTap: () => Navigator.pop(context, ChatAttachChoice.camera),
          ),
          ListTile(
            leading: const Icon(Icons.insert_drive_file_rounded, color: ChatTheme.purple),
            title: const Text('Document'),
            subtitle: const Text('PDF, docs, and more'),
            onTap: () => Navigator.pop(context, ChatAttachChoice.document),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<List<PickedGalleryMedia>> pickChatAttachments(BuildContext context, ChatAttachChoice choice) async {
  final picker = ImagePicker();
  switch (choice) {
    case ChatAttachChoice.gallery:
      final files = await picker.pickMultipleMedia(imageQuality: 80, maxWidth: 1600);
      return files.map(pickedGalleryMediaFromXFile).whereType<PickedGalleryMedia>().toList();
    case ChatAttachChoice.camera:
      if (!context.mounted) return const [];
      final cameraChoice = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded, color: ChatTheme.purple),
                title: const Text('Take photo'),
                onTap: () => Navigator.pop(context, 'photo'),
              ),
              ListTile(
                leading: const Icon(Icons.videocam_rounded, color: ChatTheme.purple),
                title: const Text('Record video'),
                onTap: () => Navigator.pop(context, 'video'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      XFile? file;
      if (cameraChoice == 'photo') {
        file = await picker.pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 1600);
      } else if (cameraChoice == 'video') {
        file = await picker.pickVideo(source: ImageSource.camera);
      }
      if (file == null) return const [];
      final media = pickedGalleryMediaFromXFile(file);
      return media == null ? const [] : [media];
    case ChatAttachChoice.document:
      return pickDocumentAttachments();
  }
}

Future<PickedGalleryMedia?> pickChatAttachment(BuildContext context, ChatAttachChoice choice) async {
  final list = await pickChatAttachments(context, choice);
  if (list.isEmpty) return null;
  return list.first;
}
