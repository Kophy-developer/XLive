import 'package:flutter/material.dart';
import 'auth_constants.dart';
import 'auth_widgets.dart';

class ResetSuccessScreen extends StatelessWidget {
  const ResetSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Icon(Icons.check_circle_rounded, size: 88, color: AuthColors.green.withValues(alpha: 0.9)),
            const SizedBox(height: 24),
            const Text(
              'Password reset successful',
              textAlign: TextAlign.center,
              style: TextStyle(color: AuthColors.black, fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: AuthPurpleButton(
                label: 'Back to login',
                onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/auth/sign-in', (r) => false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
