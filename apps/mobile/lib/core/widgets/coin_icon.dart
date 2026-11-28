import 'package:flutter/material.dart';

class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 18, this.color = const Color(0xFFFFD700)});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(color, Colors.white, 0.35)!,
              color,
              Color.lerp(color, Colors.black, 0.18)!,
            ],
          ),
          border: Border.all(color: Color.lerp(color, Colors.white, 0.45)!, width: size * 0.08),
        ),
        child: Center(
          child: Icon(Icons.toll_rounded, color: Colors.white, size: size * 0.62),
        ),
      ),
    );
  }
}
