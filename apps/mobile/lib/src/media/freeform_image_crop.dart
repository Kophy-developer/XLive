import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

Future<String?> openFreeformImageCrop(BuildContext context, String imagePath) {
  return Navigator.push<String>(
    context,
    MaterialPageRoute<String>(
      fullscreenDialog: true,
      builder: (_) => FreeformImageCropScreen(imagePath: imagePath),
    ),
  );
}

class FreeformImageCropScreen extends StatefulWidget {
  const FreeformImageCropScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<FreeformImageCropScreen> createState() => _FreeformImageCropScreenState();
}

class _FreeformImageCropScreenState extends State<FreeformImageCropScreen> {
  ui.Image? _decoded;
  Size _viewSize = Size.zero;
  Rect _crop = Rect.zero;
  bool _ready = false;
  bool _saving = false;

  static const _minCrop = 48.0;
  static const _handle = 28.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await File(widget.imagePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (!mounted) return;
    setState(() {
      _decoded = frame.image;
      _ready = true;
    });
  }

  Rect _imageRect(Size view) {
    final image = _decoded;
    if (image == null || view.isEmpty) return Rect.zero;
    final imageAspect = image.width / image.height;
    final viewAspect = view.width / view.height;
    double w;
    double h;
    if (imageAspect > viewAspect) {
      w = view.width;
      h = w / imageAspect;
    } else {
      h = view.height;
      w = h * imageAspect;
    }
    final left = (view.width - w) / 2;
    final top = (view.height - h) / 2;
    return Rect.fromLTWH(left, top, w, h);
  }

  void _ensureCrop(Size view) {
    final imageRect = _imageRect(view);
    if (imageRect.isEmpty) return;
    if (_crop == Rect.zero || _viewSize != view) {
      final inset = math.min(imageRect.width, imageRect.height) * 0.08;
      _crop = Rect.fromLTRB(
        imageRect.left + inset,
        imageRect.top + inset,
        imageRect.right - inset,
        imageRect.bottom - inset,
      );
      _viewSize = view;
    }
  }

  Rect _clampCrop(Rect next, Rect imageRect) {
    var left = next.left.clamp(imageRect.left, imageRect.right - _minCrop);
    var top = next.top.clamp(imageRect.top, imageRect.bottom - _minCrop);
    var right = next.right.clamp(left + _minCrop, imageRect.right);
    var bottom = next.bottom.clamp(top + _minCrop, imageRect.bottom);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  Future<void> _save() async {
    final image = _decoded;
    if (image == null || _saving) return;
    setState(() => _saving = true);
    try {
      final imageRect = _imageRect(_viewSize);
      final scaleX = image.width / imageRect.width;
      final scaleY = image.height / imageRect.height;
      final x = ((_crop.left - imageRect.left) * scaleX).round().clamp(0, image.width - 1);
      final y = ((_crop.top - imageRect.top) * scaleY).round().clamp(0, image.height - 1);
      var w = (_crop.width * scaleX).round();
      var h = (_crop.height * scaleY).round();
      if (x + w > image.width) w = image.width - x;
      if (y + h > image.height) h = image.height - y;
      if (w < 2 || h < 2) throw Exception('Crop area too small');

      final bytes = await File(widget.imagePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('Could not read image');
      final cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
      final dir = await getTemporaryDirectory();
      final out = '${dir.path}/crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(out).writeAsBytes(img.encodeJpg(cropped, quality: 92));
      if (!mounted) return;
      Navigator.pop(context, out);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Crop failed: $e')));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Crop', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: _saving || !_ready ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Done', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
      body: !_ready || _decoded == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white54))
          : LayoutBuilder(
              builder: (context, constraints) {
                final view = Size(constraints.maxWidth, constraints.maxHeight);
                _ensureCrop(view);
                final imageRect = _imageRect(view);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fromRect(
                      rect: imageRect,
                      child: Image.file(File(widget.imagePath), fit: BoxFit.fill),
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _CropShadePainter(imageRect: imageRect, crop: _crop),
                      ),
                    ),
                    Positioned.fromRect(
                      rect: _crop,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ),
                    _corner(imageRect, Alignment.topLeft, (d) {
                      setState(() {
                        _crop = _clampCrop(
                          Rect.fromLTRB(_crop.left + d.dx, _crop.top + d.dy, _crop.right, _crop.bottom),
                          imageRect,
                        );
                      });
                    }),
                    _corner(imageRect, Alignment.topRight, (d) {
                      setState(() {
                        _crop = _clampCrop(
                          Rect.fromLTRB(_crop.left, _crop.top + d.dy, _crop.right + d.dx, _crop.bottom),
                          imageRect,
                        );
                      });
                    }),
                    _corner(imageRect, Alignment.bottomLeft, (d) {
                      setState(() {
                        _crop = _clampCrop(
                          Rect.fromLTRB(_crop.left + d.dx, _crop.top, _crop.right, _crop.bottom + d.dy),
                          imageRect,
                        );
                      });
                    }),
                    _corner(imageRect, Alignment.bottomRight, (d) {
                      setState(() {
                        _crop = _clampCrop(
                          Rect.fromLTRB(_crop.left, _crop.top, _crop.right + d.dx, _crop.bottom + d.dy),
                          imageRect,
                        );
                      });
                    }),
                    Positioned.fromRect(
                      rect: _crop.deflate(_handle),
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setState(() {
                            final moved = _crop.shift(details.delta);
                            final dx = moved.left < imageRect.left
                                ? imageRect.left - _crop.left
                                : (moved.right > imageRect.right ? imageRect.right - _crop.right : details.delta.dx);
                            final dy = moved.top < imageRect.top
                                ? imageRect.top - _crop.top
                                : (moved.bottom > imageRect.bottom ? imageRect.bottom - _crop.bottom : details.delta.dy);
                            _crop = _crop.shift(Offset(dx, dy));
                          });
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _corner(Rect imageRect, Alignment alignment, void Function(Offset delta) onDrag) {
    final left = alignment.x < 0 ? _crop.left - _handle / 2 : _crop.right - _handle / 2;
    final top = alignment.y < 0 ? _crop.top - _handle / 2 : _crop.bottom - _handle / 2;
    return Positioned(
      left: left,
      top: top,
      width: _handle,
      height: _handle,
      child: GestureDetector(
        onPanUpdate: (details) => onDrag(details.delta),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),
      ),
    );
  }
}

class _CropShadePainter extends CustomPainter {
  _CropShadePainter({required this.imageRect, required this.crop});

  final Rect imageRect;
  final Rect crop;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    final path = Path()
      ..addRect(imageRect)
      ..addRect(crop)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CropShadePainter oldDelegate) {
    return oldDelegate.crop != crop || oldDelegate.imageRect != imageRect;
  }
}
