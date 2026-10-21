import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/session/auth_session.dart';
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
  bool _checking = false;
  bool? _usernameAvailable;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _user.dispose();
    super.dispose();
  }

  Future<void> _checkUsername() async {
    final username = _user.text.trim();
    if (username.length <= 3) {
      setState(() => _usernameAvailable = null);
      return;
    }
    setState(() {
      _checking = true;
      _usernameAvailable = null;
    });
    try {
      await AuthSession.instance.authRepository.checkAvailability(username);
      if (!mounted) return;
      setState(() => _usernameAvailable = true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _usernameAvailable = e.statusCode == 409 ? false : null);
      if (e.statusCode != 409) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = _user.text.trim();
    final showAvail = u.length > 3;

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
                    onChanged: (_) {
                      setState(() => _usernameAvailable = null);
                      _checkUsername();
                    },
                    decoration: authInputDecoration(hintText: 'Username').copyWith(
                      suffixIcon: _user.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () => setState(() {
                                _user.clear();
                                _usernameAvailable = null;
                              }),
                              icon: Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(color: AuthColors.black, shape: BoxShape.circle),
                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                              ),
                            ),
                    ),
                  ),
                  if (showAvail && _checking) ...[
                    const SizedBox(height: 10),
                    Text('Checking username…', textAlign: TextAlign.center, style: TextStyle(color: AuthColors.grey, fontSize: 14)),
                  ] else if (showAvail && _usernameAvailable == true) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, color: AuthColors.green, size: 18),
                        const SizedBox(width: 6),
                        const Text(
                          'Username is available',
                          style: TextStyle(color: AuthColors.green, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ],
                    ),
                  ] else if (showAvail && _usernameAvailable == false) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cancel_rounded, color: Colors.red.shade400, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Username is taken',
                          style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
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
                  if (first.isEmpty || last.isEmpty || username.length <= 3) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your name and a username longer than 3 characters.')));
                    return;
                  }
                  if (_usernameAvailable == false) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a different username.')));
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
