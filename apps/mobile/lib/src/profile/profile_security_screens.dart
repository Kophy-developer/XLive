import 'package:flutter/material.dart';

import '../../core/session/auth_session.dart';

const _purple = Color(0xFF8A2DDC);
const _black = Color(0xFF0A0A0A);
const _navy = Color(0xFF000022);

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _passcodeEnabled = false;
  bool _permissionsEnabled = true;
  bool _loadingPasscode = true;

  @override
  void initState() {
    super.initState();
    _loadPasscodeState();
  }

  Future<void> _loadPasscodeState() async {
    final enabled = await AuthSession.instance.passcodeEnabled();
    if (!mounted) return;
    setState(() {
      _passcodeEnabled = enabled;
      _loadingPasscode = false;
    });
  }

  Future<void> _onPasscodeToggle(bool wantOn) async {
    if (!wantOn) {
      final pin = await Navigator.push<String>(
        context,
        MaterialPageRoute<String>(
          fullscreenDialog: true,
          builder: (_) => const PasscodeEntryScreen(title: 'Enter current passcode'),
        ),
      );
      if (!mounted) return;
      if (pin == null || pin.length != 4) return;
      try {
        await AuthSession.instance.verifyPasscode(pin);
        await AuthSession.instance.removePasscode();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
        return;
      }
      setState(() => _passcodeEnabled = false);
      return;
    }
    final pin = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (_) => const PasscodeEntryScreen(title: 'Enter a passcode'),
      ),
    );
    if (!mounted) return;
    if (pin == null || pin.length != 4) return;
    final confirmed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => PasscodeConfirmScreen(expectedPin: pin),
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      try {
        await AuthSession.instance.setPasscode(pin);
        if (!mounted) return;
        setState(() => _passcodeEnabled = true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text('Security', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _black)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, '/profile/reset-password'),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Reset Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _black)),
                          const SizedBox(height: 4),
                          Text(
                            'Change your old password to a new password',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 24),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Passcode', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _black)),
                    const SizedBox(height: 4),
                    Text(
                      'Use a extra layer of security to log in anytime you open Xlive',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch.adaptive(
                value: _passcodeEnabled,
                onChanged: _loadingPasscode ? null : _onPasscodeToggle,
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return Colors.white;
                  return Colors.grey.shade400;
                }),
                trackColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return _purple;
                  return Colors.grey.shade300;
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Security and Permissions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _black)),
                    const SizedBox(height: 4),
                    Text(
                      'Request permission to perform any publics access',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch.adaptive(
                value: _permissionsEnabled,
                onChanged: (v) => setState(() => _permissionsEnabled = v),
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return Colors.white;
                  return Colors.grey.shade400;
                }),
                trackColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return _purple;
                  return Colors.grey.shade300;
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PasscodeEntryScreen extends StatefulWidget {
  const PasscodeEntryScreen({super.key, required this.title});

  final String title;

  @override
  State<PasscodeEntryScreen> createState() => _PasscodeEntryScreenState();
}

class _PasscodeEntryScreenState extends State<PasscodeEntryScreen> {
  final StringBuffer _digits = StringBuffer();

  void _addDigit(String d) {
    if (_digits.length >= 4) return;
    setState(() => _digits.write(d));
    if (_digits.length == 4) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, _digits.toString());
      });
    }
  }

  void _backspace() {
    if (_digits.isEmpty) return;
    setState(() {
      final s = _digits.toString();
      _digits.clear();
      _digits.write(s.substring(0, s.length - 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    final len = _digits.length;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: _navy, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 40, color: _navy),
                  const SizedBox(height: 20),
                  Text(
                    widget.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _navy),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      final filled = i < len;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled ? _navy : const Color(0xFFD1D1D1),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            _PasscodeKeypad(
              onDigit: _addDigit,
              onBackspace: _backspace,
            ),
            SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
          ],
        ),
      ),
    );
  }
}

class PasscodeConfirmScreen extends StatefulWidget {
  const PasscodeConfirmScreen({super.key, required this.expectedPin});

  final String expectedPin;

  @override
  State<PasscodeConfirmScreen> createState() => _PasscodeConfirmScreenState();
}

class _PasscodeConfirmScreenState extends State<PasscodeConfirmScreen> {
  final StringBuffer _digits = StringBuffer();

  void _addDigit(String d) {
    if (_digits.length >= 4) return;
    setState(() => _digits.write(d));
    if (_digits.length == 4) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_digits.toString() == widget.expectedPin) {
          Navigator.pop(context, true);
        } else {
          setState(() {
            _digits.clear();
          });
        }
      });
    }
  }

  void _backspace() {
    if (_digits.isEmpty) return;
    setState(() {
      final s = _digits.toString();
      _digits.clear();
      _digits.write(s.substring(0, s.length - 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    final len = _digits.length;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: _navy, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 40, color: _navy),
                  const SizedBox(height: 20),
                  const Text(
                    'Confirm a passcode',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _navy),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      final filled = i < len;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled ? _navy : const Color(0xFFD1D1D1),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            _PasscodeKeypad(
              onDigit: _addDigit,
              onBackspace: _backspace,
            ),
            SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
          ],
        ),
      ),
    );
  }
}

class _PasscodeKeypad extends StatelessWidget {
  const _PasscodeKeypad({required this.onDigit, required this.onBackspace});

  final void Function(String) onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onTap, Widget? child}) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
                color: Colors.white,
              ),
              alignment: Alignment.center,
              child: child ?? Text(label, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w500, color: _navy)),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: ['1', '2', '3'].map((d) => key(d, onTap: () => onDigit(d))).toList(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: ['4', '5', '6'].map((d) => key(d, onTap: () => onDigit(d))).toList(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: ['7', '8', '9'].map((d) => key(d, onTap: () => onDigit(d))).toList(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 92, height: 92),
              key('0', onTap: () => onDigit('0')),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onBackspace,
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: Icon(Icons.backspace_outlined, size: 28, color: _navy),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  bool _hideOld = true;
  bool _hideNew = true;
  String? _serverNewPasswordError;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    super.dispose();
  }

  bool get _lenOk => validateAuthPassword(_newCtrl.text) == null;
  String? get _newPasswordError =>
      _serverNewPasswordError ?? (_newCtrl.text.isEmpty ? null : validateAuthPassword(_newCtrl.text));
  bool get _canSubmit => _oldCtrl.text.isNotEmpty && validateAuthPassword(_newCtrl.text) == null;

  InputDecoration _fieldDeco(String label, {required bool obscure, required VoidCallback toggle}) {
    return InputDecoration(
      labelText: label,
      floatingLabelStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      labelStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      suffixIcon: IconButton(
        onPressed: toggle,
        icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey.shade600),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: const BorderSide(color: _purple, width: 1.5)),
    );
  }

  Widget _reqRow(String text, bool met) {
    final c = met ? _navy : Colors.grey.shade500;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.withValues(alpha: 0.5))),
            child: Icon(Icons.check_rounded, size: 14, color: c),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.35)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text('Reset Password', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _black)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _oldCtrl,
                    obscureText: _hideOld,
                    onChanged: (_) => setState(() {}),
                    decoration: _fieldDeco('Old Password', obscure: _hideOld, toggle: () => setState(() => _hideOld = !_hideOld)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _newCtrl,
                    obscureText: _hideNew,
                    onChanged: (_) => setState(() => _serverNewPasswordError = null),
                    decoration: _fieldDeco('New Password', obscure: _hideNew, toggle: () => setState(() => _hideNew = !_hideNew))
                        .copyWith(errorText: _newPasswordError),
                  ),
                  const SizedBox(height: 24),
                  _reqRow('Must be at least $authPasswordMinLength characters', _lenOk),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + MediaQuery.paddingOf(context).bottom),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _canSubmit
                    ? () async {
                        try {
                          await AuthSession.instance.changePassword(
                            currentPassword: _oldCtrl.text,
                            newPassword: _newCtrl.text,
                          );
                          if (!context.mounted) return;
                          final messenger = ScaffoldMessenger.maybeOf(context);
                          Navigator.pop(context);
                          messenger?.showSnackBar(const SnackBar(content: Text('Password updated')));
                        } catch (e) {
                          if (!context.mounted) return;
                          final passwordError = serverPasswordError(e);
                          if (passwordError != null) {
                            setState(() => _serverNewPasswordError = passwordError);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
                          }
                        }
                      }
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  elevation: 0,
                ),
                child: const Text('Reset Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
