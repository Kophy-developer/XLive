import 'package:image_picker/image_picker.dart';

import 'media_picker_utils.dart';

class EditedMediaResult {
  const EditedMediaResult({required this.path, required this.isVideo});

  final String path;
  final bool isVideo;

  PickedGalleryMedia toPickedMedia() {
    return PickedGalleryMedia(file: XFile(path), isVideo: isVideo);
  }
}

enum MediaCropAspect { original, square, portrait, landscape }

enum MediaEditorTool { edit, music, voice, filter, addVideo }

class MediaFilterPreset {
  const MediaFilterPreset({required this.id, required this.label, this.ffmpeg, this.matrix});

  final String id;
  final String label;
  final String? ffmpeg;
  final List<double>? matrix;
}

const mediaFilterPresets = <MediaFilterPreset>[
  MediaFilterPreset(id: 'none', label: 'Original'),
  MediaFilterPreset(
    id: 'warm',
    label: 'Warm',
    ffmpeg: 'colorbalance=rs=0.12:gs=0.04:bs=-0.08,hue=s=1.12',
    matrix: <double>[
      1.08, 0, 0, 0, 18,
      0, 1.02, 0, 0, 6,
      0, 0, 0.94, 0, 0,
      0, 0, 0, 1, 0,
    ],
  ),
  MediaFilterPreset(
    id: 'cool',
    label: 'Cool',
    ffmpeg: 'colorbalance=rs=-0.08:gs=0.0:bs=0.12,hue=s=1.06',
    matrix: <double>[
      0.94, 0, 0, 0, 0,
      0, 1.02, 0, 0, 4,
      0, 0, 1.1, 0, 14,
      0, 0, 0, 1, 0,
    ],
  ),
  MediaFilterPreset(
    id: 'vivid',
    label: 'Vivid',
    ffmpeg: 'colorchannelmixer=rr=1.15:gg=1.15:bb=1.15,hue=s=1.4',
    matrix: <double>[
      1.12, 0, 0, 0, 0,
      0, 1.12, 0, 0, 0,
      0, 0, 1.12, 0, 0,
      0, 0, 0, 1, 0,
    ],
  ),
  MediaFilterPreset(
    id: 'mono',
    label: 'Mono',
    ffmpeg: 'hue=s=0',
    matrix: <double>[
      0.33, 0.33, 0.33, 0, 0,
      0.33, 0.33, 0.33, 0, 0,
      0.33, 0.33, 0.33, 0, 0,
      0, 0, 0, 1, 0,
    ],
  ),
];

class MediaEditProject {
  const MediaEditProject({
    required this.sourcePath,
    required this.isVideo,
    this.trimStartSec = 0,
    this.trimEndSec = 30,
    this.durationSec = 30,
    this.cropAspect = MediaCropAspect.original,
    this.filterId = 'none',
    this.addedVideoPath,
    this.musicPath,
    this.voicePath,
    this.musicTitle,
    this.musicStartSec = 0,
    this.musicDurationSec = 0,
    this.muteOriginal = false,
    this.originalVolume = 1,
    this.musicVolume = 0.65,
    this.voiceVolume = 1,
  });

  final String sourcePath;
  final bool isVideo;
  final double trimStartSec;
  final double trimEndSec;
  final double durationSec;
  final MediaCropAspect cropAspect;
  final String filterId;
  final String? addedVideoPath;
  final String? musicPath;
  final String? voicePath;
  final String? musicTitle;
  final double musicStartSec;
  final double musicDurationSec;
  final bool muteOriginal;
  final double originalVolume;
  final double musicVolume;
  final double voiceVolume;

  bool get hasMusic => musicPath != null && musicPath!.isNotEmpty;
  bool get hasVoice => voicePath != null && voicePath!.isNotEmpty;
  bool get hasAddedVideo => addedVideoPath != null && addedVideoPath!.isNotEmpty;
  bool get hasAudioExtras => hasMusic || hasVoice;
  bool get resultIsVideo => isVideo || hasAudioExtras || hasAddedVideo;

  bool get isUnchangedExport {
    if (hasAudioExtras || hasAddedVideo) return false;
    if (filterId != 'none') return false;
    if (cropAspect != MediaCropAspect.original) return false;
    if (muteOriginal) return false;
    if (!isVideo) return true;
    if (trimStartSec > 0.05) return false;
    if (durationSec > 0 && trimEndSec < durationSec - 0.05) return false;
    return true;
  }

  double get clipDurationSec {
    final span = (trimEndSec - trimStartSec).clamp(0.5, durationSec <= 0 ? 30.0 : durationSec);
    return span;
  }

  double get maxMusicStartSec {
    if (musicDurationSec <= 0) return 0;
    final maxStart = musicDurationSec - clipDurationSec;
    return maxStart < 0 ? 0 : maxStart;
  }

  MediaFilterPreset get filter =>
      mediaFilterPresets.firstWhere((f) => f.id == filterId, orElse: () => mediaFilterPresets.first);

  MediaEditProject copyWith({
    String? sourcePath,
    double? trimStartSec,
    double? trimEndSec,
    double? durationSec,
    MediaCropAspect? cropAspect,
    String? filterId,
    String? addedVideoPath,
    bool clearAddedVideo = false,
    String? musicPath,
    bool clearMusic = false,
    String? musicTitle,
    double? musicStartSec,
    double? musicDurationSec,
    String? voicePath,
    bool clearVoice = false,
    bool? muteOriginal,
    double? originalVolume,
    double? musicVolume,
    double? voiceVolume,
  }) {
    return MediaEditProject(
      sourcePath: sourcePath ?? this.sourcePath,
      isVideo: isVideo,
      trimStartSec: trimStartSec ?? this.trimStartSec,
      trimEndSec: trimEndSec ?? this.trimEndSec,
      durationSec: durationSec ?? this.durationSec,
      cropAspect: cropAspect ?? this.cropAspect,
      filterId: filterId ?? this.filterId,
      addedVideoPath: clearAddedVideo ? null : addedVideoPath ?? this.addedVideoPath,
      musicPath: clearMusic ? null : musicPath ?? this.musicPath,
      musicTitle: clearMusic ? null : musicTitle ?? this.musicTitle,
      musicStartSec: clearMusic ? 0 : musicStartSec ?? this.musicStartSec,
      musicDurationSec: clearMusic ? 0 : musicDurationSec ?? this.musicDurationSec,
      voicePath: clearVoice ? null : voicePath ?? this.voicePath,
      muteOriginal: muteOriginal ?? this.muteOriginal,
      originalVolume: originalVolume ?? this.originalVolume,
      musicVolume: musicVolume ?? this.musicVolume,
      voiceVolume: voiceVolume ?? this.voiceVolume,
    );
  }
}
