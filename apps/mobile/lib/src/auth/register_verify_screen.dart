import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/session/auth_session.dart';
import '../../features/auth/models/auth_models.dart';
import '../profile/profile_screens.dart';
import 'auth_constants.dart';
import 'auth_widgets.dart';

class RegisterVerifyScreen extends StatefulWidget {
  const RegisterVerifyScreen({
    super.key,
    required this.draft,
    required this.destinationLine,
    required this.verificationType,
    this.highlightWholeLine = false,
    this.emailHighlight = '',
    this.onVerified,
    this.onResend,
  });

  final RegisterDraft draft;
  final String destinationLine;
  final String verificationType;
  final bool highlightWholeLine;
  final String emailHighlight;
  final Future<void> Function(String code)? onVerified;
  final Future<void> Function()? onResend;

  @override
  State<RegisterVerifyScreen> createState() => _RegisterVerifyScreenState();
}

class _RegisterVerifyScreenState extends State<RegisterVerifyScreen> {
  int _seconds = 27;
  Timer? _t;
  bool _submitting = false;
  final _codeCtrl = TextEditingController();

  void _restartTimer() {
    _t?.cancel();
    setState(() => _seconds = 27);
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_seconds > 0) {
          _seconds -= 1;
        }
        if (_seconds <= 0) {
          _t?.cancel();
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void dispose() {
    _t?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    if (widget.onResend != null) {
      await widget.onResend!();
      _restartTimer();
      return;
    }
    final email = widget.draft.email?.trim();
    if (email == null || email.isEmpty) return;
    try {
      await AuthSession.instance.authRepository.resendVerification(email);
      _restartTimer();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('A new code was sent to $email.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
    }
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the 6-digit code from your email.')));
      return;
    }
    final email = widget.draft.email?.trim();
    if (widget.onVerified == null && (email == null || email.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Missing email for verification.')));
      return;
    }

    setState(() => _submitting = true);
    try {
      if (widget.onVerified != null) {
        await widget.onVerified!(code);
        return;
      }
      final draft = widget.draft;
      final displayName = [draft.firstName, draft.lastName].where((s) => s != null && s.trim().isNotEmpty).join(' ').trim();
      await AuthSession.instance.verifyEmailAndSignIn(
        email: email!,
        code: code,
        displayName: displayName.isEmpty ? null : displayName,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
      if (!mounted) return;
      await Navigator.push<bool>(context, MaterialPageRoute<bool>(builder: (_) => const EditProfileScreen()));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mm = _seconds ~/ 60;
    final ss = _seconds % 60;
    final timerLabel = '${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
    final title = widget.verificationType == 'email' ? 'Verify your email' : 'Verify your number';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AuthScrollBody(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTopBar(
              showBack: true,
              showClose: true,
              onClose: () => authPopUntilCreateAccount(context),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AuthColors.black, fontSize: 26, fontWeight: FontWeight.w800, height: 1.2),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _DestinationText(
                prefix: 'A code was sent to ',
                highlight: widget.emailHighlight.isNotEmpty ? widget.emailHighlight : widget.destinationLine,
                suffix: '',
                highlightAsPurple: true,
                fullPurple: widget.highlightWholeLine,
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, letterSpacing: 4, fontWeight: FontWeight.w500),
                decoration: authInputDecoration(hintText: '000-000'),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              "Didn't get a code?",
              textAlign: TextAlign.center,
              style: TextStyle(color: AuthColors.grey, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: OutlinedButton(
                onPressed: _seconds > 0 || _submitting ? null : _resend,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: AuthColors.grey,
                  side: const BorderSide(color: AuthColors.border),
                  backgroundColor: AuthColors.resendBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: Text(
                  _seconds > 0 ? 'Resend Code ($timerLabel)' : 'Resend Code',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: AuthPurpleButton(
                label: _submitting ? 'Verifying…' : 'Next',
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
      ),
    );
  }
}

class _DestinationText extends StatelessWidget {
  const _DestinationText({
    required this.prefix,
    required this.highlight,
    required this.suffix,
    required this.highlightAsPurple,
    required this.fullPurple,
  });

  final String prefix;
  final String highlight;
  final String suffix;
  final bool highlightAsPurple;
  final bool fullPurple;

  @override
  Widget build(BuildContext context) {
    if (fullPurple) {
      return Text(
        '$prefix$highlight$suffix',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AuthColors.grey, fontSize: 15, height: 1.45),
      );
    }
    return Text.rich(
      TextSpan(
        style: const TextStyle(color: AuthColors.grey, fontSize: 15, height: 1.45),
        children: [
          TextSpan(text: prefix),
          TextSpan(
            text: highlight,
            style: TextStyle(color: highlightAsPurple ? AuthColors.purple : AuthColors.grey, fontWeight: FontWeight.w600),
          ),
          TextSpan(text: suffix),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
