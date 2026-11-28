import 'package:flutter/material.dart';

import '../../features/auth/models/auth_models.dart';
import 'auth_constants.dart';
import 'auth_widgets.dart';
import 'register_email_screen.dart';

class RegisterNameScreen extends StatefulWidget {
  const RegisterNameScreen({super.key, required this.draft});

  final RegisterDraft draft;

  @override
  State<RegisterNameScreen> createState() => _RegisterNameScreenState();
}

class _RegisterNameScreenState extends State<RegisterNameScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _user = TextEditingController();
  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _user.dispose();
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
              "What's your name?",
              textAlign: TextAlign.center,
              style: TextStyle(color: AuthColors.black, fontSize: 26, fontWeight: FontWeight.w800, height: 1.2),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'It will be displayed on your profile. Only username will display.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AuthColors.grey, fontSize: 15, height: 1.45),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _first,
                    onChanged: (_) => setState(() {}),
                    decoration: authInputDecoration(hintText: 'Fist Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _last,
                    onChanged: (_) => setState(() {}),
                    decoration: authInputDecoration(hintText: 'Last Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _user,
                    onChanged: (_) => setState(() {}),
                    decoration: authInputDecoration(hintText: 'Username').copyWith(
                      suffixIcon: _user.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () => setState(_user.clear),
                              icon: Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(color: AuthColors.black, shape: BoxShape.circle),
                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: AuthPurpleButton(
                label: 'Next',
                onPressed: () {
                  final first = _first.text.trim();
                  final last = _last.text.trim();
                  final username = _user.text.trim();
                  if (first.isEmpty || last.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your first and last name.')));
                    return;
                  }
                  // Backend rule (POST /auth/create): 3-30 characters, no spaces.
                  // Uniqueness is enforced by the server when the account is created.
                  if (!RegExp(r'^\S{3,30}$').hasMatch(username)) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username must be 3-30 characters with no spaces.')));
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => RegisterEmailScreen(
                        draft: widget.draft.copyWith(firstName: first, lastName: last, username: username),
                      ),
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
