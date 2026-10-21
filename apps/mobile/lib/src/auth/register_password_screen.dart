import 'package:flutter/material.dart';

import '../../core/session/auth_session.dart';
import '../../features/auth/models/auth_models.dart';
import 'auth_constants.dart';
import 'auth_widgets.dart';
import 'register_name_screen.dart';

class RegisterPasswordScreen extends StatefulWidget {
  const RegisterPasswordScreen({super.key, required this.draft});

  final RegisterDraft draft;

  @override
  State<RegisterPasswordScreen> createState() => _RegisterPasswordScreenState();
}

class _RegisterPasswordScreenState extends State<RegisterPasswordScreen> {
  bool _obscure = true;
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
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
              'Set up your password',
              textAlign: TextAlign.center,
              style: TextStyle(color: AuthColors.black, fontSize: 26, fontWeight: FontWeight.w800, height: 1.2),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'Enter the password you will like to use to login your account',
                textAlign: TextAlign.center,
                style: TextStyle(color: AuthColors.grey, fontSize: 15, height: 1.45),
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                decoration: authInputDecoration(hintText: 'Enter Password').copyWith(
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AuthColors.grey, size: 22),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your password must be at least 8 characters.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AuthColors.grey, fontSize: 13),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: AuthPurpleButton(
                label: 'Next',
                onPressed: () {
                  final password = _passwordCtrl.text;
                  final error = validateAuthPassword(password);
                  if (error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => RegisterNameScreen(draft: widget.draft.copyWith(password: password)),
                    ),
                  );
                },
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
