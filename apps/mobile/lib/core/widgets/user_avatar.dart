import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.imageUrl,
    required this.radius,
    this.iconSize,
    this.backgroundColor,
    this.iconColor,
    this.isLive = false,
  });

  final String? imageUrl;
  final double radius;
  final double? iconSize;
  final Color? backgroundColor;
  final Color? iconColor;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final hasImage = url != null && url.isNotEmpty;
    final bg = backgroundColor ?? Colors.grey.shade200;
    final fg = iconColor ?? Colors.grey.shade500;
    final size = radius * 2;
    final icon = Icon(Icons.person_rounded, size: iconSize ?? radius, color: fg);

    Widget avatar;
    if (!hasImage) {
      avatar = CircleAvatar(radius: radius, backgroundColor: bg, child: icon);
    } else {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        child: ClipOval(
          child: Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => icon,
          ),
        ),
      );
    }

    if (!isLive) return avatar;

    return _LiveGlowAvatar(radius: radius, avatar: avatar);
  }
}

class _LiveGlowAvatar extends StatefulWidget {
  const _LiveGlowAvatar({required this.radius, required this.avatar});

  final double radius;
  final Widget avatar;

  @override
  State<_LiveGlowAvatar> createState() => _LiveGlowAvatarState();
}

class _LiveGlowAvatarState extends State<_LiveGlowAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringPad = (widget.radius * 0.14).clamp(2.0, 4.0);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        final glow = 4.0 + (t * 8.0);
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(ringPad),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    Color(0xFFE11D48),
                    Color(0xFFFF6B8A),
                    Color(0xFFE11D48),
                    Color(0xFFFB7185),
                    Color(0xFFE11D48),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE11D48).withValues(alpha: 0.35 + (t * 0.35)),
                    blurRadius: glow,
                    spreadRadius: 0.5 + (t * 1.5),
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black),
                child: child,
              ),
            ),
            Positioned(
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.45),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: (widget.radius * 0.28).clamp(8.0, 11.0),
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: widget.avatar,
    );
  }
}

class GroupAvatar extends StatelessWidget {
  const GroupAvatar({
    super.key,
    this.imageUrl,
    required this.radius,
    this.iconSize,
    this.backgroundColor,
    this.iconColor,
  });

  final String? imageUrl;
  final double radius;
  final double? iconSize;
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final hasImage = url != null && url.isNotEmpty;
    final bg = backgroundColor ?? Colors.grey.shade200;
    final fg = iconColor ?? Colors.grey.shade500;
    final size = radius * 2;
    final icon = Icon(Icons.groups_rounded, size: iconSize ?? radius, color: fg);

    if (!hasImage) {
      return CircleAvatar(radius: radius, backgroundColor: bg, child: icon);
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => icon,
        ),
      ),
    );
  }
}
