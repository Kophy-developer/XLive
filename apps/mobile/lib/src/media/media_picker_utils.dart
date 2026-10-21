import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

enum GalleryMediaKind { image, video, imageOrVideo }

class PickedGalleryMedia {
  const PickedGalleryMedia({
    required this.file,
    required this.isVideo,
    this.isDocument = false,
  });

  final XFile file;
  final bool isVideo;
  final bool isDocument;
}

bool isVideoFilename(String name) {
  final lower = name.toLowerCase();
  return lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.m4v') ||
      lower.endsWith('.avi') ||
      lower.endsWith('.mkv') ||
      lower.endsWith('.webm');
}

bool isImageFilename(String name) {
  final lower = name.toLowerCase();
  return lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.heic') ||
      lower.endsWith('.heif');
}

bool isVideoMime(String? mime) {
  final m = mime?.toLowerCase() ?? '';
  return m.startsWith('video/');
}

bool isImageMime(String? mime) {
  final m = mime?.toLowerCase() ?? '';
  return m.startsWith('image/');
}

PickedGalleryMedia? pickedGalleryMediaFromXFile(XFile file) {
  final video = isVideoMime(file.mimeType) || isVideoFilename(file.name);
  final image = isImageMime(file.mimeType) || isImageFilename(file.name);
  if (!video && !image) return null;
  return PickedGalleryMedia(file: file, isVideo: video);
}

String uploadFilenameFor(PickedGalleryMedia media) {
  var name = media.file.name.trim();
  if (name.isEmpty) {
    final pathName = media.file.path.split(RegExp(r'[/\\]')).last.trim();
    name = pathName;
  }
  if (name.isEmpty) return media.isVideo ? 'upload.mp4' : 'upload.jpg';
  if (media.isVideo) {
    if (!isVideoFilename(name)) {
      final dot = name.lastIndexOf('.');
      name = dot > 0 ? '${name.substring(0, dot)}.mp4' : '$name.mp4';
    }
  } else if (!isImageFilename(name)) {
    final dot = name.lastIndexOf('.');
    name = dot > 0 ? '${name.substring(0, dot)}.jpg' : '$name.jpg';
  }
  return name;
}

String? imageExtensionFromMagic(List<int> bytes) {
  if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return 'jpg';
  if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return 'png';
  if (bytes.length >= 6 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x38) {
    return 'gif';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'webp';
  }
  return null;
}

String uploadFilenameForImageBytes(PickedGalleryMedia media, List<int> bytes) {
  final base = uploadFilenameFor(media);
  if (media.isVideo) return base;
  final sniffed = imageExtensionFromMagic(bytes);
  if (sniffed == null) return base;
  final lower = base.toLowerCase();
  if (lower.endsWith('.$sniffed') || (sniffed == 'jpg' && lower.endsWith('.jpeg'))) return base;
  final dot = base.lastIndexOf('.');
  if (dot <= 0) return '$base.$sniffed';
  return '${base.substring(0, dot)}.$sniffed';
}

Future<String?> videoThumbnailPath(String videoPath) async {
  return VideoThumbnail.thumbnailFile(
    video: videoPath,
    imageFormat: ImageFormat.JPEG,
    maxHeight: 720,
    quality: 85,
    timeMs: 200,
  );
}

Future<PickedGalleryMedia?> pickGalleryMedia(
  BuildContext context, {
  required GalleryMediaKind kind,
  bool allowCamera = true,
}) async {
  final items = await pickGalleryMediaMulti(
    context,
    kind: kind,
    allowCamera: allowCamera,
    allowMultiple: false,
  );
  if (items.isEmpty) return null;
  return items.first;
}

Future<List<PickedGalleryMedia>> pickGalleryMediaMulti(
  BuildContext context, {
  required GalleryMediaKind kind,
  bool allowCamera = true,
  bool allowMultiple = true,
}) async {
  final picker = ImagePicker();
  final choice = await showModalBottomSheet<_GalleryPickChoice>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          if (kind == GalleryMediaKind.imageOrVideo) ...[
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF8A2DDC)),
              title: const Text('Gallery'),
              subtitle: Text(allowMultiple ? 'Photos or videos' : 'Photo or video'),
              onTap: () => Navigator.pop(context, _GalleryPickChoice.gallery),
            ),
            if (allowCamera)
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded, color: Color(0xFF8A2DDC)),
                title: const Text('Camera'),
                subtitle: const Text('Photo or video'),
                onTap: () => Navigator.pop(context, _GalleryPickChoice.camera),
              ),
          ] else ...[
            if (kind != GalleryMediaKind.video)
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF8A2DDC)),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, _GalleryPickChoice.galleryImage),
              ),
            if (kind == GalleryMediaKind.video)
              ListTile(
                leading: const Icon(Icons.video_library_rounded, color: Color(0xFF8A2DDC)),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, _GalleryPickChoice.galleryVideo),
              ),
            if (allowCamera && kind != GalleryMediaKind.video)
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded, color: Color(0xFF8A2DDC)),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, _GalleryPickChoice.cameraImage),
              ),
            if (allowCamera && kind != GalleryMediaKind.image)
              ListTile(
                leading: const Icon(Icons.videocam_rounded, color: Color(0xFF8A2DDC)),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, _GalleryPickChoice.cameraVideo),
              ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return const [];

  switch (choice) {
    case _GalleryPickChoice.gallery:
      if (allowMultiple) {
        final files = await picker.pickMultipleMedia();
        return files.map(pickedGalleryMediaFromXFile).whereType<PickedGalleryMedia>().toList();
      }
      final file = await picker.pickMedia();
      if (file == null) return const [];
      final media = pickedGalleryMediaFromXFile(file);
      return media == null ? const [] : [media];
    case _GalleryPickChoice.camera:
      final cameraChoice = await showModalBottomSheet<_GalleryPickChoice>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded, color: Color(0xFF8A2DDC)),
                title: const Text('Take photo'),
                onTap: () => Navigator.pop(context, _GalleryPickChoice.cameraImage),
              ),
              ListTile(
                leading: const Icon(Icons.videocam_rounded, color: Color(0xFF8A2DDC)),
                title: const Text('Record video'),
                onTap: () => Navigator.pop(context, _GalleryPickChoice.cameraVideo),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      XFile? file;
      if (cameraChoice == _GalleryPickChoice.cameraImage) {
        file = await picker.pickImage(source: ImageSource.camera);
      } else if (cameraChoice == _GalleryPickChoice.cameraVideo) {
        file = await picker.pickVideo(source: ImageSource.camera);
      }
      if (file == null) return const [];
      final media = pickedGalleryMediaFromXFile(file);
      return media == null ? const [] : [media];
    case _GalleryPickChoice.galleryImage:
      if (allowMultiple) {
        final files = await picker.pickMultiImage();
        return files.map(pickedGalleryMediaFromXFile).whereType<PickedGalleryMedia>().toList();
      }
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null) return const [];
      final media = pickedGalleryMediaFromXFile(file);
      return media == null ? const [] : [media];
    case _GalleryPickChoice.galleryVideo:
      final file = await picker.pickVideo(source: ImageSource.gallery);
      if (file == null) return const [];
      final media = pickedGalleryMediaFromXFile(file);
      return media == null ? const [] : [media];
    case _GalleryPickChoice.cameraImage:
      final file = await picker.pickImage(source: ImageSource.camera);
      if (file == null) return const [];
      final media = pickedGalleryMediaFromXFile(file);
      return media == null ? const [] : [media];
    case _GalleryPickChoice.cameraVideo:
      final file = await picker.pickVideo(source: ImageSource.camera);
      if (file == null) return const [];
      final media = pickedGalleryMediaFromXFile(file);
      return media == null ? const [] : [media];
  }
}

Future<List<PickedGalleryMedia>> pickDocumentAttachments({bool allowMultiple = true}) async {
  final result = await FilePicker.pickFiles(
    allowMultiple: allowMultiple,
    type: FileType.custom,
    allowedExtensions: const ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx', 'zip', 'csv'],
    withData: false,
  );
  if (result == null) return const [];
  final out = <PickedGalleryMedia>[];
  for (final file in result.files) {
    final path = file.path;
    if (path == null || path.isEmpty) continue;
    out.add(
      PickedGalleryMedia(
        file: XFile(path, name: file.name),
        isVideo: false,
        isDocument: true,
      ),
    );
  }
  return out;
}

enum _GalleryPickChoice {
  gallery,
  camera,
  galleryImage,
  galleryVideo,
  cameraImage,
  cameraVideo,
}
