import 'package:flutter/material.dart';
import 'package:logbook_app_001/features/auth/login_view.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  static const List<_OnboardingItem> _items = [
    _OnboardingItem(
      title: 'Catat Aktivitas',
      description: 'Simpan log harian dengan rapi dan cepat.',
      imagePath: 'assets/images/onboarding1.png',
    ),
    _OnboardingItem(
      title: 'Pantau Progres',
      description: 'Lihat perkembangan setiap hari dalam satu tempat.',
      imagePath: 'assets/images/onboarding2.png',
    ),
    _OnboardingItem(
      title: 'Mulai Sekarang',
      description: 'Masuk dan kelola logbook kamu dengan mudah.',
      imagePath: 'assets/images/onboarding3.png',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginView()),
    );
  }

  void _nextPage() {
    if (_currentIndex < _items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _goToLogin();
    }
  }

  void _skipToEnd() {
    _pageController.animateToPage(
      _items.length - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _items.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          item.imagePath,
                          height: 220,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.description,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _currentIndex == _items.length - 1
                        ? null
                        : _skipToEnd,
                    child: const Text('Lewati'),
                  ),
                  Row(
                    children: List.generate(
                      _items.length,
                      (index) =>
                          _DotIndicator(isActive: index == _currentIndex),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _nextPage,
                    child: Text(
                      _currentIndex == _items.length - 1
                          ? 'Mulai'
                          : 'Berikutnya',
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

class _OnboardingItem {
  final String title;
  final String description;
  final String imagePath;

  const _OnboardingItem({
    required this.title,
    required this.description,
    required this.imagePath,
  });
}

class _DotIndicator extends StatelessWidget {
  final bool isActive;

  const _DotIndicator({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      height: 8,
      width: isActive ? 20 : 8,
      decoration: BoxDecoration(
        color: isActive
            ? Theme.of(context).colorScheme.primary
            : Colors.grey.shade400,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
