import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/session/auth_session.dart';
import '../../features/auth/models/auth_models.dart';
import 'auth_constants.dart';
import 'auth_country_code_field.dart';
import 'auth_widgets.dart';
import 'register_password_screen.dart';

class RegisterPhoneScreen extends StatefulWidget {
  const RegisterPhoneScreen({super.key, this.draft});

  final RegisterDraft? draft;

  @override
  State<RegisterPhoneScreen> createState() => _RegisterPhoneScreenState();
}

class _RegisterPhoneScreenState extends State<RegisterPhoneScreen> {
  late Country _country;
  final _phone = TextEditingController();
  bool _checking = false;
  bool? _phoneAvailable;

  @override
  void initState() {
    super.initState();
    _country = authDefaultCountry();
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _checkPhone(String e164) async {
    setState(() {
      _checking = true;
      _phoneAvailable = null;
    });
    try {
      await AuthSession.instance.authRepository.checkAvailability(e164);
      if (!mounted) return;
      setState(() => _phoneAvailable = true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _phoneAvailable = e.statusCode == 409 ? false : null);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            const Text(
              "What's your number?",
              textAlign: TextAlign.center,
              style: TextStyle(color: AuthColors.black, fontSize: 26, fontWeight: FontWeight.w800, height: 1.2),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'Your phone number is required for your account. It will never appear on your profile.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AuthColors.grey, fontSize: 15, height: 1.45),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuthCountryCodeField(
                    country: _country,
                    onTap: () => showAuthCountryPicker(context, (c) => setState(() => _country = c)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      onChanged: (_) => setState(() => _phoneAvailable = null),
                      decoration: authInputDecoration(hintText: '000 000 000').copyWith(
                        suffixIcon: _phoneAvailable == false
                            ? const Icon(Icons.error_outline, color: Colors.redAccent)
                            : _phoneAvailable == true
                                ? const Icon(Icons.check_circle_outline, color: AuthColors.purple)
                                : null,
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
                onPressed: _checking
                    ? null
                    : () async {
                  final digits = _phone.text.trim();
                  if (digits.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your phone number.')));
                    return;
                  }
                  final e164 = '${_country.phoneCode}${digits.replaceAll(RegExp(r'\D'), '')}';
                  await _checkPhone(e164);
                  if (!mounted) return;
                  if (_phoneAvailable == false) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That phone number is already in use.')));
                    return;
                  }
                  final draft = (widget.draft ?? RegisterDraft()).copyWith(
                    phoneDigits: digits.replaceAll(RegExp(r'\D'), ''),
                    phoneCountryCode: _country.phoneCode,
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => RegisterPasswordScreen(draft: draft)),
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
      ),
    );
  }
}
