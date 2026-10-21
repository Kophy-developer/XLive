import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/session/auth_session.dart';
import '../../features/auth/models/auth_models.dart';
import 'auth_constants.dart';
import 'auth_widgets.dart';
import 'register_verify_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _usernameMode = true;
  bool _obscure = true;
  bool _submitting = false;
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final email = widget.initialEmail?.trim();
    if (email != null && email.isNotEmpty) {
      _usernameMode = false;
      _emailCtrl.text = email;
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordCtrl.text;
    final passwordError = validateAuthPassword(password);
    if (passwordError != null) {
      _showError(passwordError);
      return;
    }

    final identifier = _usernameMode ? _usernameCtrl.text.trim() : _emailCtrl.text.trim();
    if (identifier.isEmpty) {
      _showError(_usernameMode ? 'Enter your username.' : 'Enter your email address.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await AuthSession.instance.signInWithCredentials(
        identifier: identifier,
        password: password,
        email: _usernameMode ? null : identifier,
        username: _usernameMode ? identifier : null,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
    } on VerificationRequiredException catch (e) {
      if (!mounted) return;
      await _openVerification(e);
    } on BridgeUserNotFoundException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openVerification(VerificationRequiredException e) async {
    try {
      await AuthSession.instance.authRepository.requestVerificationCode(
        userId: e.userId,
        type: e.verificationType,
      );
    } catch (err) {
      _showError(authErrorMessage(err));
      return;
    }
    if (!mounted) return;
    final destination = e.verificationType == 'email' ? (e.email ?? e.identifier) : e.identifier;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RegisterVerifyScreen(
          draft: RegisterDraft(
            userId: e.userId,
            email: e.email,
            password: e.password,
            username: e.username,
          ),
          destinationLine: destination,
          emailHighlight: e.verificationType == 'email' ? destination : '',
          verificationType: e.verificationType,
          onVerified: (code) async {
            await AuthSession.instance.signInAfterVerifyCode(
              userId: e.userId,
              code: code,
              verificationType: e.verificationType,
              identifier: e.identifier,
              password: e.password,
              email: e.email,
              phone: e.phone,
              username: e.username,
            );
            if (!context.mounted) return;
            Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
          },
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
            const SizedBox(height: 8),
            Text(
              'Welcome back',
              textAlign: TextAlign.center,
              style: TextStyle(color: AuthColors.grey.withValues(alpha: 0.95), fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sign in',
              textAlign: TextAlign.center,
              style: TextStyle(color: AuthColors.black, fontSize: 28, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.5),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Pick up where you left off — your profile, wallet, and studio stay in sync.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AuthColors.grey.withValues(alpha: 0.9), fontSize: 14, height: 1.45, fontWeight: FontWeight.w400),
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _Segmented(
                left: 'Username',
                right: 'Email',
                leftSelected: _usernameMode,
                onLeft: () => setState(() => _usernameMode = true),
                onRight: () => setState(() => _usernameMode = false),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_usernameMode) ...[
                      TextField(
                        controller: _usernameCtrl,
                        textCapitalization: TextCapitalization.none,
                        autocorrect: false,
                        decoration: authInputDecoration(hintText: 'Username'),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        decoration: authInputDecoration(hintText: 'Password').copyWith(
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AuthColors.grey, size: 22),
                          ),
                        ),
                      ),
                    ] else ...[
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: authInputDecoration(hintText: 'Email address'),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        decoration: authInputDecoration(hintText: 'Password').copyWith(
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AuthColors.grey, size: 22),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/auth/forgot-password'),
                        child: const Text(
                          'Forgot Password',
                          style: TextStyle(color: AuthColors.black, fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                    ),
                    const Spacer(),
                    AuthPurpleButton(
                      label: _submitting ? 'Signing in…' : 'Sign in',
                      onPressed: _submitting ? null : _submit,
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.left,
    required this.right,
    required this.leftSelected,
    required this.onLeft,
    required this.onRight,
  });

  final String left;
  final String right;
  final bool leftSelected;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AuthColors.chipBg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onLeft,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: leftSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: leftSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))] : null,
                ),
                child: Text(left, style: TextStyle(fontWeight: FontWeight.w700, color: leftSelected ? AuthColors.black : AuthColors.grey)),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onRight,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: !leftSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: !leftSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))] : null,
                ),
                child: Text(right, style: TextStyle(fontWeight: FontWeight.w700, color: !leftSelected ? AuthColors.black : AuthColors.grey)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
