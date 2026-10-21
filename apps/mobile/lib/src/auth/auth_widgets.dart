import 'package:flutter/material.dart';
import 'auth_constants.dart';
import '../legal/legal_report_screens.dart';

void authPopUntilCreateAccount(BuildContext context) {
  Navigator.popUntil(context, (r) => r.settings.name == '/auth/create-account');
}

class AuthIosStatusBar extends StatelessWidget {
  const AuthIosStatusBar({super.key, required this.light});

  final bool light;

  @override
  Widget build(BuildContext context) {
    final c = light ? Colors.white : AuthColors.black;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
      child: Row(
        children: [
          Text('8:00', style: TextStyle(fontWeight: FontWeight.w600, color: c, fontSize: 15)),
          const Spacer(),
          Icon(Icons.signal_cellular_alt_rounded, size: 18, color: c),
          const SizedBox(width: 5),
          Icon(Icons.wifi_rounded, size: 18, color: c),
          const SizedBox(width: 5),
          Icon(Icons.battery_full_rounded, size: 22, color: c),
        ],
      ),
    );
  }
}

class AuthNavCircleButton extends StatelessWidget {
  const AuthNavCircleButton({super.key, required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AuthColors.navCircle,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: AuthColors.black),
        ),
      ),
    );
  }
}

class AuthTopBar extends StatelessWidget {
  const AuthTopBar({super.key, this.showBack = false, this.showClose = true, this.onBack, required this.onClose});

  final bool showBack;
  final bool showClose;
  final VoidCallback? onBack;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        children: [
          if (showBack)
            AuthNavCircleButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: onBack ?? () => Navigator.maybePop(context))
          else
            const SizedBox(width: 40, height: 40),
          const Spacer(),
          if (showClose)
            AuthNavCircleButton(icon: Icons.close_rounded, onPressed: onClose)
          else
            const SizedBox(width: 40, height: 40),
        ],
      ),
    );
  }
}

InputDecoration authInputDecoration({String? hintText, Widget? suffixIcon}) {
  const r = BorderRadius.all(Radius.circular(26));
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 16),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    filled: true,
    fillColor: Colors.white,
    border: const OutlineInputBorder(borderRadius: r, borderSide: BorderSide(color: AuthColors.border)),
    enabledBorder: const OutlineInputBorder(borderRadius: r, borderSide: BorderSide(color: AuthColors.border)),
    focusedBorder: const OutlineInputBorder(borderRadius: r, borderSide: BorderSide(color: AuthColors.purple, width: 1.5)),
    suffixIcon: suffixIcon,
  );
}

class AuthPurpleButton extends StatelessWidget {
  const AuthPurpleButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AuthColors.purple,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AuthColors.purple.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          elevation: 0,
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      ),
    );
  }
}

class AuthLegalFooter extends StatelessWidget {
  const AuthLegalFooter({super.key, this.light = false});

  final bool light;

  @override
  Widget build(BuildContext context) {
    final baseColor = light ? Colors.white.withValues(alpha: 0.85) : AuthColors.grey;
    final linkColor = light ? Colors.white : const Color(0xFF4A4A4A);
    final baseStyle = TextStyle(fontSize: 12, color: baseColor, height: 1.4);
    final linkStyle = TextStyle(fontWeight: FontWeight.w700, color: linkColor, fontSize: 12, height: 1.4);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text.rich(
        TextSpan(
          style: baseStyle,
          children: [
            const TextSpan(text: 'By registering, you accept our '),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: GestureDetector(
                onTap: () => showTermsOfUseSheet(context),
                child: Text('Terms and Conditions', style: linkStyle),
              ),
            ),
            TextSpan(text: ' and ', style: baseStyle),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: GestureDetector(
                onTap: () => showPrivacyPolicySheet(context),
                child: Text('Privacy Policy', style: linkStyle),
              ),
            ),
            const TextSpan(text: '.'),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class AuthXliveLogoMark extends StatelessWidget {
  const AuthXliveLogoMark({super.key, required this.color, this.size = 48});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.chat_bubble_rounded, color: color, size: size * 0.95),
        Transform.translate(
          offset: Offset(-size * 0.22, 0),
          child: Icon(Icons.videocam_rounded, color: color, size: size * 0.78),
        ),
      ],
    );
  }
}
