import 'package:flutter/material.dart';

import '../../core/session/auth_session.dart';
import '../../features/auth/models/auth_models.dart';
import 'auth_constants.dart';
import 'auth_widgets.dart';
import 'register_verify_screen.dart';
import 'reset_new_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the email on your account.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await AuthSession.instance.authRepository.forgotPassword(email);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => RegisterVerifyScreen(
            draft: RegisterDraft(email: email),
            destinationLine: email,
            emailHighlight: email,
            highlightWholeLine: false,
            verificationType: 'email',
            onVerified: (code) async {
              if (!context.mounted) return;
              await Navigator.pushReplacement<void, void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ResetNewPasswordScreen(identifier: email, code: code),
                ),
              );
            },
            onResend: () => AuthSession.instance.authRepository.forgotPassword(email),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: AuthNavCircleButton(
                  icon: Icons.close_rounded,
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Forgot your password?',
              textAlign: TextAlign.center,
              style: TextStyle(color: AuthColors.black, fontSize: 26, fontWeight: FontWeight.w800, height: 1.2),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'Enter your account email and we will send you a code to reset your password.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AuthColors.grey, fontSize: 15, height: 1.45),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: authInputDecoration(hintText: 'Email Address'),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: AuthPurpleButton(
                label: _submitting ? 'Sending…' : 'Next',
                onPressed: _submitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
