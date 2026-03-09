import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/prefs_service.dart';
import '../theme/dokki_theme.dart';
import '../main.dart'; // Для доступа к AppInitScreen

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  // Assets defined here
  static const String _assetPage1 =
      'assets/onboarding/onboarding_1_ai_voice.png';
  static const String _assetPage2 =
      'assets/onboarding/onboarding_2_autodelete.png';
  static const String _assetPage3 =
      'assets/onboarding/onboarding_3_encryption.png';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Updated onboarding page data - images already contain all text
  final List<OnboardingData> _pages = [
    OnboardingData(
      assetPath: OnboardingScreen._assetPage1,
      title: '',
      description: '',
    ),
    OnboardingData(
      assetPath: OnboardingScreen._assetPage2,
      title: '',
      description: '',
    ),
    OnboardingData(
      assetPath: OnboardingScreen._assetPage3,
      title: '',
      description: '',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentPage) {
        setState(() {
          _currentPage = page;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Complete onboarding and go to HomeScreen
  Future<void> _completeOnboarding() async {
    await prefs.setOnboardingCompleted(true);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppInitScreen()),
      );
    }
  }

  /// Open privacy policy
  Future<void> _launchPrivacyPolicy() async {
    final Uri url = Uri.parse('https://www.dokki.org/privacy');
    if (!await launchUrl(url)) {
      // Ignore error in production
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.grey.withValues(alpha: 0.7),
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return OnboardingPage(data: _pages[index]);
                },
              ),
            ),

            // Dot indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => _buildDot(index),
                ),
              ),
            ),

            // Get Started button and Privacy Policy link
            Padding(
              padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
              child: _currentPage == _pages.length - 1
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _completeOnboarding,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DokkiColors.primaryTeal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Get Started',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _launchPrivacyPolicy,
                          child: const Text(
                            'Privacy Policy',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(height: 88),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    final isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive
            ? DokkiColors.primaryTeal
            : Colors.grey.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class OnboardingData {
  final String assetPath;
  final String title;
  final String description;

  OnboardingData({
    required this.assetPath,
    required this.title,
    required this.description,
  });
}

class OnboardingPage extends StatelessWidget {
  final OnboardingData data;

  const OnboardingPage({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        data.assetPath,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
      ),
    );
  }
}
