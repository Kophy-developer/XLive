import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/session/auth_session.dart';
import '../../features/auth/models/auth_models.dart';
import 'auth_constants.dart';
import 'auth_widgets.dart';
import 'register_verify_screen.dart';

class RegisterEmailScreen extends StatefulWidget {
  const RegisterEmailScreen({super.key, required this.draft});

  final RegisterDraft draft;

  @override
  State<RegisterEmailScreen> createState() => _RegisterEmailScreenState();
}

class _RegisterEmailScreenState extends State<RegisterEmailScreen> {
  final _email = TextEditingController();
  bool _submitting = false;
  bool _checking = false;
  bool? _emailAvailable;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _checkEmail() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _emailAvailable = null);
      return;
    }
    setState(() {
      _checking = true;
      _emailAvailable = null;
    });
    try {
      await AuthSession.instance.authRepository.checkAvailability(email);
      if (!mounted) return;
      setState(() => _emailAvailable = true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _emailAvailable = e.statusCode == 409 ? false : null);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid email address.')));
      return;
    }
    if (_emailAvailable == false) {
      await _promptExistingAccount(email);
      return;
    }
    final draft = widget.draft;
    final password = draft.password;
    if (password == null || validateAuthPassword(password) != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(validateAuthPassword(password ?? '') ?? '')));
      return;
    }

    setState(() => _submitting = true);
    try {
      await AuthSession.instance.authRepository.register(
        email: email,
        firstName: draft.firstName ?? '',
        lastName: draft.lastName ?? '',
        username: draft.username ?? '',
        phone: draft.phoneE164,
        password: password,
      );
      if (!mounted) return;
      final nextDraft = draft.copyWith(email: email);
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => RegisterVerifyScreen(
            draft: nextDraft,
            destinationLine: email,
            emailHighlight: email,
            verificationType: 'email',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Shows the server's message, e.g. a duplicate username or email, or its password rule.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(serverPasswordError(e) ?? authErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _promptExistingAccount(String email) async {
    final signIn = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Account already exists'),
        content: Text('$email is already registered. Sign in instead?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign in')),
        ],
      ),
    );
    if (signIn == true && mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/auth/sign-in', (route) => false, arguments: email);
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
              onClose: () => authPopUntilCreateAccount(context),
            ),
            const SizedBox(height: 8),
            const Text(
              "What's your email?",
              textAlign: TextAlign.center,
              style: TextStyle(color: AuthColors.black, fontSize: 26, fontWeight: FontWeight.w800, height: 1.2),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'We will send a verification code to this address to activate your account. You can also use it to recover your login.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AuthColors.grey, fontSize: 15, height: 1.45),
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) {
                  setState(() => _emailAvailable = null);
                  _checkEmail();
                },
                decoration: authInputDecoration(hintText: 'Email Address').copyWith(
                  suffixIcon: _checking
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : _emailAvailable == true
                          ? const Icon(Icons.check_circle_outline, color: AuthColors.purple)
                          : _emailAvailable == false
                              ? const Icon(Icons.error_outline, color: Colors.redAccent)
                              : null,
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: AuthPurpleButton(
                label: _submitting ? 'Creating account…' : 'Next',
                onPressed: _submitting ? null : _submit,
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: AuthLegalFooter(),
            ),
          ],
        ),
      ),
    );
  }
}
