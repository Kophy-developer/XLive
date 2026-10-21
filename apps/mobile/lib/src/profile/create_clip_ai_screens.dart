import 'package:flutter/material.dart';

class ClipPreviewScreen extends StatelessWidget {
  const ClipPreviewScreen({super.key, required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8E8ED),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: SizedBox(
                  width: constraints.maxWidth - 32,
                  height: constraints.maxHeight - 24,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(imageUrl, fit: BoxFit.cover),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
