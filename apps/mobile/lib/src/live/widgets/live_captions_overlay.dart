import 'package:flutter/material.dart';

class LiveCaptionsOverlay extends StatelessWidget {
  const LiveCaptionsOverlay({
    super.key,
    required this.visible,
    required this.lines,
  });

  final bool visible;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    if (!visible || lines.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < lines.length; i++) ...[
                    if (i > 0) const SizedBox(height: 4),
                    Text(
                      lines[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: i == lines.length - 1 ? 1 : 0.78),
                        fontSize: i == lines.length - 1 ? 16 : 14,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LiveHearTranslateToggleButton extends StatelessWidget {
  const LiveHearTranslateToggleButton({
    super.key,
    required this.enabled,
    required this.active,
    required this.onPressed,
  });

  final bool enabled;
  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    final iconColor = active ? const Color(0xFF0A0A0A) : Colors.white;
    return Semantics(
      button: true,
      label: 'Hear translation',
      toggled: active,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Align(
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF34D399).withValues(alpha: 0.92) : Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                ),
                child: Icon(Icons.headphones_rounded, color: iconColor, size: 18),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LiveAiTranslatorToggleButton extends StatelessWidget {
  const LiveAiTranslatorToggleButton({
    super.key,
    required this.enabled,
    required this.active,
    required this.onPressed,
  });

  final bool enabled;
  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    final iconColor = active ? const Color(0xFF0A0A0A) : Colors.white;
    return Semantics(
      button: true,
      label: 'AI Translator',
      toggled: active,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Align(
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? Colors.white.withValues(alpha: 0.94) : Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                    ),
                    child: Icon(Icons.translate_rounded, color: iconColor, size: 18),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1.5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF8A2DDC), Color(0xFF35D3FB)]),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.35), width: 1),
                      boxShadow: const [
                        BoxShadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 1)),
                      ],
                    ),
                    child: const Text(
                      'AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
