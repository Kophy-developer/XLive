import 'package:flutter/material.dart';

import '../../core/session/auth_session.dart';
import 'auth_constants.dart';
import 'auth_widgets.dart';
import 'reset_success_screen.dart';

class ResetNewPasswordScreen extends StatefulWidget {
  const ResetNewPasswordScreen({super.key, required this.identifier, required this.code});

  final String identifier;
  final String code;

  @override
  State<ResetNewPasswordScreen> createState() => _ResetNewPasswordScreenState();
}

class _ResetNewPasswordScreenState extends State<ResetNewPasswordScreen> {
  bool _o1 = true;
  bool _o2 = true;
  bool _submitting = false;
  bool _showErrors = false;
  String? _serverPasswordError;
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? get _passwordError {
    final text = _passwordCtrl.text;
    if (_serverPasswordError != null) return _serverPasswordError;
    return _showErrors || text.isNotEmpty ? validateAuthPassword(text) : null;
  }

  String? get _confirmError {
    final confirm = _confirmCtrl.text;
    if (!_showErrors && confirm.isEmpty) return null;
    return confirm == _passwordCtrl.text ? null : authPasswordMismatchMessage;
  }

  Future<void> _submit() async {
    final password = _passwordCtrl.text;
    if (validateAuthPassword(password) != null || password != _confirmCtrl.text) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() => _submitting = true);
    try {
      await AuthSession.instance.authRepository.resetPassword(
        email: widget.identifier,
        code: widget.code.replaceAll(RegExp(r'\D'), ''),
        newPassword: password,
      );
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute<void>(builder: (_) => const ResetSuccessScreen()));
    } catch (e) {
      if (!mounted) return;
      final passwordError = serverPasswordError(e);
      if (passwordError != null) {
        setState(() => _serverPasswordError = passwordError);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
      }
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
            AuthTopBar(
              showBack: true,
              showClose: true,
              onClose: () => Navigator.pushNamedAndRemoveUntil(context, '/auth/sign-in', (r) => false),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter new password',
              textAlign: TextAlign.center,
              style: TextStyle(color: AuthColors.black, fontSize: 26, fontWeight: FontWeight.w800, height: 1.2),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _o1,
                    onChanged: (_) => setState(() => _serverPasswordError = null),
                    decoration: authInputDecoration(hintText: 'New Password').copyWith(
                      errorText: _passwordError,
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _o1 = !_o1),
                        icon: Icon(_o1 ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AuthColors.grey, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _confirmCtrl,
                    obscureText: _o2,
                    onChanged: (_) => setState(() {}),
                    decoration: authInputDecoration(hintText: 'Confirm Password').copyWith(
                      errorText: _confirmError,
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _o2 = !_o2),
                        icon: Icon(_o2 ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AuthColors.grey, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: AuthPurpleButton(
                label: _submitting ? 'Saving…' : 'Next',
                onPressed: _submitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
