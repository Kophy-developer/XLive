import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DarkOnboardingScreen extends StatefulWidget {
  const DarkOnboardingScreen({super.key});

  @override
  State<DarkOnboardingScreen> createState() => _DarkOnboardingScreenState();
}

class _DarkOnboardingScreenState extends State<DarkOnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _titles = [
    'Discover & Connect with Creators',
    'Monetize your Content',
    'AI-enhanced streaming',
  ];

  static const _bodies = [
    'Explore live experiences, join real-time conversations, and build meaningful connections with creators from around the world.',
    'Turn your passion into profit with private sessions, subscriptions, gifts, and smart revenue tools designed to help you earn effortlessly.',
    'Stream smarter with real-time translation, automated highlights, intelligent moderation, and privacy protection powered by advanced AI.',
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/onboarding/Onboarding background.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: PageView(
                            controller: _controller,
                            onPageChanged: (i) => setState(() => _index = i),
                            children: const [
                              _HeroPage(child: _Slide1Hero()),
                              _HeroPage(child: _Slide2Hero()),
                              _HeroPage(child: _Slide3Hero()),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _OnboardingPagination(activeIndex: _index),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        Text(
                          _titles[_index],
                          textAlign: TextAlign.center,
                          key: ValueKey<String>(_titles[_index]),
                          style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700, height: 1.15),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _bodies[_index],
                          textAlign: TextAlign.center,
                          key: ValueKey<String>(_bodies[_index]),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 16, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: _GradientCta(
                      label: _index < 2 ? 'Next' : 'Get Started',
                      onPressed: () {
                        if (_index < 2) {
                          _controller.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
                        } else {
                          Navigator.pushReplacementNamed(context, '/auth/create-account');
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 15),
                        children: [
                          const TextSpan(text: 'Already have an account? '),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: GestureDetector(
                              onTap: () => Navigator.pushNamed(context, '/auth/sign-in'),
                              child: const Text(
                                'Sign in',
                                style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPage extends StatelessWidget {
  const _HeroPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: child,
    );
  }
}

class _OnboardingPagination extends StatelessWidget {
  const _OnboardingPagination({required this.activeIndex});

  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final active = i == activeIndex;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: active ? 28 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
      }),
    );
  }
}

class _GradientCta extends StatelessWidget {
  const _GradientCta({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          height: 56,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF8A2DDC), Color(0xFF35D3FB)]),
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
            ),
          ),
        ),
      ),
    );
  }
}

class _Slide1Hero extends StatelessWidget {
  const _Slide1Hero();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: Image.asset(
            'assets/onboarding/1/Img Wrapper.png',
            fit: BoxFit.contain,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            alignment: Alignment.bottomCenter,
          ),
        );
      },
    );
  }
}

class _Slide2Hero extends StatelessWidget {
  const _Slide2Hero();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/onboarding/2/Img.png',
                    fit: BoxFit.contain,
                  ),
                ),
                Positioned.fill(
                  child: Image.asset(
                    'assets/onboarding/2/Container.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Slide3Hero extends StatelessWidget {
  const _Slide3Hero();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: Image.asset(
            'assets/onboarding/3/Img.png',
            fit: BoxFit.contain,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            alignment: Alignment.center,
          ),
        );
      },
    );
  }
}
