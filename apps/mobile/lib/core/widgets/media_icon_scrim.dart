import 'package:flutter/material.dart';

class MediaIconScrim extends StatelessWidget {
  const MediaIconScrim({super.key, required this.child, this.size = 36, this.onTap});

  final Widget child;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final core = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.38),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return core;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: core);
  }
}
