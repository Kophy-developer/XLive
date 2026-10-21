import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'media_editor_models.dart';

class MediaComposer {
  static Future<String> export(MediaEditProject project) async {
    if (project.isUnchangedExport) return project.sourcePath;
    if (project.resultIsVideo) {
      if (project.isVideo) return _exportVideo(project);
      return _exportImageAsVideo(project);
    }
    return _exportImage(project);
  }

  static Future<String> _exportImage(MediaEditProject project) async {
    final bytes = await File(project.sourcePath).readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) throw Exception('Could not read image');

    image = _cropImage(image, project.cropAspect);
    image = _applyImageFilter(image, project.filterId);

    final dir = await getTemporaryDirectory();
    final out = '${dir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(out).writeAsBytes(img.encodeJpg(image, quality: 90));
    return out;
  }

  static Future<String> _exportImageAsVideo(MediaEditProject project) async {
    final still = await _exportImage(project);
    final dir = await getTemporaryDirectory();
    final out = '${dir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final duration = project.hasMusic || project.hasVoice ? 15.0 : 8.0;
    final clip = duration.toStringAsFixed(2);
    final musicStart = project.musicStartSec.clamp(0, project.maxMusicStartSec);

    final args = <String>['-y', '-loop', '1', '-t', clip, '-i', still];
    var next = 1;
    int? musicIdx;
    int? voiceIdx;
    int? videoIdx;

    if (project.hasAddedVideo) {
      videoIdx = next;
      args.addAll(['-t', clip, '-i', project.addedVideoPath!]);
      next++;
    }
    if (project.hasMusic) {
      musicIdx = next;
      args.addAll(['-ss', musicStart.toStringAsFixed(2), '-t', clip, '-i', project.musicPath!]);
      next++;
    }
    if (project.hasVoice) {
      voiceIdx = next;
      args.addAll(['-t', clip, '-i', project.voicePath!]);
      next++;
    }

    final vFilters = <String>[];
    var vMap = '0:v';
    if (project.hasAddedVideo) {
      vFilters.add('[$videoIdx:v]scale=iw*0.34:-2[ov]');
      vFilters.add('[0:v][ov]overlay=W-w-16:H-h-16:shortest=1[vout]');
      vMap = '[vout]';
    }
    vFilters.add('$vMap scale=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p[vfinal]');
    vMap = '[vfinal]';

    final aFilters = <String>[];
    final aLabels = <String>[];
    var aIdx = 0;
    if (project.hasMusic) {
      aFilters.add('[$musicIdx:a]volume=${project.musicVolume.toStringAsFixed(2)},atrim=0:$clip,asetpts=PTS-STARTPTS[a$aIdx]');
      aLabels.add('[a$aIdx]');
      aIdx++;
    }
    if (project.hasVoice) {
      aFilters.add('[$voiceIdx:a]volume=${project.voiceVolume.toStringAsFixed(2)},atrim=0:$clip,asetpts=PTS-STARTPTS[a$aIdx]');
      aLabels.add('[a$aIdx]');
      aIdx++;
    }

    String? aMap;
    if (aLabels.length == 1) {
      aMap = aLabels.first;
    } else if (aLabels.length > 1) {
      aFilters.add('${aLabels.join()}amix=inputs=${aLabels.length}:duration=first:dropout_transition=0[aout]');
      aMap = '[aout]';
    }

    final filterComplex = [...vFilters, ...aFilters].join(';');
    args.addAll(['-filter_complex', filterComplex, '-map', vMap]);
    if (aMap != null) {
      args.addAll(['-map', aMap, '-c:a', 'aac', '-b:a', '128k']);
    } else {
      args.add('-an');
    }

    args.addAll([
      '-c:v', 'mpeg4',
      '-q:v', '5',
      '-t', clip,
      '-shortest',
      '-movflags', '+faststart',
      out,
    ]);

    await _runFfmpeg(args, out);
    return out;
  }

  static img.Image _applyImageFilter(img.Image image, String filterId) {
    switch (filterId) {
      case 'warm':
        return img.adjustColor(image, saturation: 1.12, gamma: 1.04);
      case 'cool':
        return img.adjustColor(image, saturation: 1.06, gamma: 0.96);
      case 'vivid':
        return img.adjustColor(image, saturation: 1.45, contrast: 1.08);
      case 'mono':
        return img.grayscale(image);
      default:
        return image;
    }
  }

  static img.Image _cropImage(img.Image image, MediaCropAspect aspect) {
    if (aspect == MediaCropAspect.original) return image;
    final target = switch (aspect) {
      MediaCropAspect.square => 1.0,
      MediaCropAspect.portrait => 4 / 5,
      MediaCropAspect.landscape => 16 / 9,
      MediaCropAspect.original => image.width / image.height,
    };
    final current = image.width / image.height;
    var cropW = image.width;
    var cropH = image.height;
    if (current > target) {
      cropW = (image.height * target).round().clamp(2, image.width);
    } else {
      cropH = (image.width / target).round().clamp(2, image.height);
    }
    final x = ((image.width - cropW) / 2).round().clamp(0, image.width - cropW);
    final y = ((image.height - cropH) / 2).round().clamp(0, image.height - cropH);
    return img.copyCrop(image, x: x, y: y, width: cropW, height: cropH);
  }

  static Future<String> _exportVideo(MediaEditProject project) async {
    final dir = await getTemporaryDirectory();
    final out = '${dir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final start = project.trimStartSec.clamp(0, project.durationSec);
    final end = project.trimEndSec.clamp(start + 0.5, project.durationSec <= 0 ? start + 0.5 : project.durationSec);
    final clipSec = end - start;
    final duration = clipSec.toStringAsFixed(2);
    final musicStart = project.musicStartSec.clamp(0, project.maxMusicStartSec);

    final hasMusic = project.hasMusic;
    final hasVoice = project.hasVoice;
    final hasCrop = project.cropAspect != MediaCropAspect.original;
    final hasFilter = project.filterId != 'none' && project.filter.ffmpeg != null;
    final needsReencode =
        hasMusic || hasVoice || hasCrop || hasFilter || project.muteOriginal || project.originalVolume != 1;

    if (!needsReencode) {
      await _runFfmpeg([
        '-y',
        '-ss',
        start.toStringAsFixed(2),
        '-t',
        duration,
        '-i',
        project.sourcePath,
        '-c',
        'copy',
        '-movflags',
        '+faststart',
        out,
      ], out);
      return out;
    }

    final args = <String>[
      '-y',
      '-ss',
      start.toStringAsFixed(2),
      '-t',
      duration,
      '-i',
      project.sourcePath,
    ];

    var nextInput = 1;
    int? musicInputIndex;
    int? voiceInputIndex;

    if (hasMusic) {
      musicInputIndex = nextInput;
      args.addAll(['-ss', musicStart.toStringAsFixed(2), '-t', duration, '-i', project.musicPath!]);
      nextInput++;
    }
    if (hasVoice) {
      voiceInputIndex = nextInput;
      args.addAll(['-t', duration, '-i', project.voicePath!]);
      nextInput++;
    }

    final vFilters = <String>[];
    var vLabel = '[0:v]';
    var vMap = '0:v';

    final crop = _ffmpegCrop(project.cropAspect);
    if (crop != null) {
      vFilters.add('$vLabel$crop[v0]');
      vLabel = '[v0]';
      vMap = '[v0]';
    }
    final eq = project.filter.ffmpeg;
    if (eq != null && project.filterId != 'none') {
      vFilters.add('$vLabel$eq[v1]');
      vLabel = '[v1]';
      vMap = '[v1]';
    }
    vFilters.add('$vLabel scale=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p[vfinal]');
    vMap = '[vfinal]';

    final aFilters = <String>[];
    final aLabels = <String>[];
    var aIdx = 0;
    if (!project.muteOriginal && (hasMusic || hasVoice)) {
      aFilters.add(
        '[0:a]volume=${project.originalVolume.toStringAsFixed(2)},atrim=0:$duration,asetpts=PTS-STARTPTS[a$aIdx]',
      );
      aLabels.add('[a$aIdx]');
      aIdx++;
    }
    if (hasMusic) {
      aFilters.add(
        '[$musicInputIndex:a]volume=${project.musicVolume.toStringAsFixed(2)},atrim=0:$duration,asetpts=PTS-STARTPTS[a$aIdx]',
      );
      aLabels.add('[a$aIdx]');
      aIdx++;
    }
    if (hasVoice) {
      aFilters.add(
        '[$voiceInputIndex:a]volume=${project.voiceVolume.toStringAsFixed(2)},atrim=0:$duration,asetpts=PTS-STARTPTS[a$aIdx]',
      );
      aLabels.add('[a$aIdx]');
      aIdx++;
    }

    String? aMap;
    if (aLabels.isNotEmpty) {
      if (aLabels.length == 1) {
        aMap = aLabels.first;
      } else {
        aFilters.add('${aLabels.join()}amix=inputs=${aLabels.length}:duration=first:dropout_transition=0[aout]');
        aMap = '[aout]';
      }
    }

    final filterComplex = [...vFilters, ...aFilters].join(';');
    args.addAll(['-filter_complex', filterComplex, '-map', vMap]);
    if (aMap != null) {
      args.addAll(['-map', aMap, '-c:a', 'aac', '-b:a', '128k']);
    } else {
      args.add('-an');
    }

    args.addAll([
      '-c:v',
      'mpeg4',
      '-q:v',
      '5',
      '-t',
      duration,
      '-shortest',
      '-movflags',
      '+faststart',
      out,
    ]);

    await _runFfmpeg(args, out);
    return out;
  }

  static Future<void> _runFfmpeg(List<String> args, String out) async {
    if (kDebugMode) debugPrint('[MediaComposer] ffmpeg ${args.join(' ')}');
    final session = await FFmpegKit.executeWithArguments(args);
    final code = await session.getReturnCode();
    if (!ReturnCode.isSuccess(code)) {
      final logs = await session.getAllLogsAsString() ?? '';
      throw Exception(logs.isEmpty ? 'Video export failed' : logs.split('\n').where((l) => l.trim().isNotEmpty).last);
    }
    if (!await File(out).exists()) throw Exception('Exported file missing');
  }

  static String? _ffmpegCrop(MediaCropAspect aspect) {
    return switch (aspect) {
      MediaCropAspect.square => 'crop=min(iw\\,ih):min(iw\\,ih):(iw-ow)/2:(ih-oh)/2',
      MediaCropAspect.portrait =>
        'crop=min(iw\\,ih*4/5):min(ih\\,iw*5/4):(iw-ow)/2:(ih-oh)/2',
      MediaCropAspect.landscape =>
        'crop=min(iw\\,ih*16/9):min(ih\\,iw*9/16):(iw-ow)/2:(ih-oh)/2',
      MediaCropAspect.original => null,
    };
  }
}
