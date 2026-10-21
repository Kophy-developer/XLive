import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'account_role.dart';
import 'auth_constants.dart';
import 'auth_widgets.dart';
import 'register_phone_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  void _continue(VoidCallback navigate) {
    ActiveAccountContext.setRole(AccountRole.creator);
    navigate();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/Bg Img.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xB36A38D8),
                    Color(0xB31E2A50),
                    Color(0xB32FA9A0),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12, top: 4),
                      child: AuthNavCircleButton(
                        icon: Icons.close_rounded,
                        onPressed: () => Navigator.maybePop(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Image.asset(
                      'assets/Group.png',
                      fit: BoxFit.contain,
                      height: 88,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Create your account',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.4),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Text(
                      'One account for everything on Xlive — go live, share clips, grow your audience, and get paid.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 15, height: 1.5, fontWeight: FontWeight.w400),
                    ),
                  ),
                  const Spacer(flex: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        _WhiteCta(
                          label: 'Continue with Password',
                          onPressed: () => _continue(() {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(builder: (_) => const RegisterPhoneScreen()),
                            );
                          }),
                        ),
                        const SizedBox(height: 20),
                        Text.rich(
                          TextSpan(
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 15),
                            children: [
                              const TextSpan(text: 'Already have an account? '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.baseline,
                                baseline: TextBaseline.alphabetic,
                                child: GestureDetector(
                                  onTap: () => Navigator.pushNamed(context, '/auth/sign-in'),
                                  child: const Text(
                                    'Sign in',
                                    style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, decoration: TextDecoration.underline, decorationColor: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        const AuthLegalFooter(light: true),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhiteCta extends StatelessWidget {
  const _WhiteCta({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AuthColors.black, fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}
