import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'login_screen.dart';
import '../core/animations/page_transitions.dart';
import '../core/animations/animation_constants.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      image: 'assets/images/icons/onboard1.png',
      title: 'Explore the\nworld easily',
      subtitle: 'To your desire',
      fallbackIcon: Icons.two_wheeler,
    ),
    OnboardingPage(
      image: 'assets/images/icons/onboard2.png',
      title: 'Reach the best\ngroup plan',
      subtitle: 'To your destination',
      fallbackIcon: Icons.groups,
    ),
    OnboardingPage(
      image: 'assets/images/icons/onboard3.png',
      title: 'Make Bonds\nwith TripBond',
      subtitle: 'In your dream trip',
      fallbackIcon: Icons.person_pin_circle,
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      SharedAxisPageRoute(page: const LoginScreen()),
    );
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: AnimationConstants.medium),
        curve: AnimationConstants.cubicEaseOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    'SKIP',
                    style: GoogleFonts.mulish(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // PageView
              SizedBox(
                height: 400,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPage(_pages[index]);
                  },
                ),
              ),

              const SizedBox(height: 40),

              // Bottom section with indicators and button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page indicators
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: index == _currentPage
                              ? const Color(0xFFC8A858)
                              : Colors.grey.shade300,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),

                  // Next button
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2D4EC8),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: _nextPage,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Illustration with scale animation
        SizedBox(
          height: 220,
          child: Image.asset(
            page.image,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                page.fallbackIcon,
                size: 150,
                color: const Color(0xFF4675B8),
              );
            },
          ),
        )
            .animate()
            .fadeIn(
              duration: const Duration(milliseconds: AnimationConstants.medium),
              curve: AnimationConstants.cubicEaseOut,
            )
            .scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1, 1),
              duration: const Duration(milliseconds: AnimationConstants.medium),
              curve: AnimationConstants.cubicEaseOut,
            ),
        const SizedBox(height: 50),

        // Title with slide up animation
        Text(
          page.title,
          textAlign: TextAlign.center,
          style: GoogleFonts.mulish(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            height: 1.3,
          ),
        )
            .animate()
            .fadeIn(
              delay: const Duration(milliseconds: 200),
              duration: const Duration(milliseconds: AnimationConstants.normal),
              curve: AnimationConstants.cubicEaseOut,
            )
            .slideY(
              begin: 0.2,
              end: 0,
              delay: const Duration(milliseconds: 200),
              duration: const Duration(milliseconds: AnimationConstants.normal),
              curve: AnimationConstants.cubicEaseOut,
            ),
        const SizedBox(height: 8),

        // Subtitle with slide up animation (delayed)
        Text(
          page.subtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.mulish(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        )
            .animate()
            .fadeIn(
              delay: const Duration(milliseconds: 400),
              duration: const Duration(milliseconds: AnimationConstants.normal),
              curve: AnimationConstants.cubicEaseOut,
            )
            .slideY(
              begin: 0.2,
              end: 0,
              delay: const Duration(milliseconds: 400),
              duration: const Duration(milliseconds: AnimationConstants.normal),
              curve: AnimationConstants.cubicEaseOut,
            ),
      ],
    );
  }
}

class OnboardingPage {
  final String image;
  final String title;
  final String subtitle;
  final IconData fallbackIcon;

  OnboardingPage({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.fallbackIcon,
  });
}
