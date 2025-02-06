import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/accessability/logic/bloc/auth/bloc/auth_bloc.dart';
import 'package:frontend/accessability/logic/bloc/auth/bloc/auth_event.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<StatefulWidget> createState() {
    return _OnboardingScreenState();
  }
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<String> _images = [
    'assets/images/onboarding/onboarding_0.png',
    'assets/images/onboarding/onboarding_1.png',
    'assets/images/onboarding/onboarding_2.png',
    'assets/images/onboarding/onboarding_3.png',
    'assets/images/onboarding/onboarding_4.png',
    'assets/images/onboarding/onboarding_5.png',
  ];

  final List<String> _descriptions = [
    'Welcome to AccessAbility a GPS app designed for persons with disabilities. It helps you mark locations and find wheelchair-friendly routes, ensuring safe and accessible travel wherever you go.',
    'Create a private space where you can invite family and friends to join. This feature allows them to track your real-time location, ensuring you’re always connected. It’s perfect for staying in touch and receiving support when needed.',
    'Within your private space, you can chat and make voice calls with family and friends. This feature allows you to easily share updates, ask for help, or simply stay connected. It ensures that communication is always just a tap away.',
    'The app includes text-to-speech and speech-to-text features to make communication easier. Text-to-speech reads content aloud, while speech-to-text converts your spoken words into text. These tools provide accessibility for a smoother experience.',
    'You can add emergency contacts to your profile for quick access in case of an emergency. The SOS feature sends an immediate distress signal with your location to alert your contacts. This ensures help is always nearby when you need it most.',
    'We’re so glad you’ve chosen our app to assist with your navigation and communication needs. Our goal is to make your journey safer and more connected. Thank you for using our app, and we hope it enhances your daily experience.',
  ];

 void _onNextPressed() {
  if (_currentPage < _images.length - 1) {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeIn,
    );
  } else {
    // Complete the onboarding process using BLoC
    print('OnboardingScreen: Dispatching CompleteOnboardingEvent');
    context.read<AuthBloc>().add(CompleteOnboardingEvent());
    // Navigate to the home screen
    Navigator.of(context).pushReplacementNamed('/homescreen');
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
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemCount: _images.length,
                      itemBuilder: (context, index) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              _images[index],
                              height: 300,
                              fit: BoxFit.cover,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _descriptions[index],
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_images.length, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == _currentPage
                              ? const Color(0xFF6750A4)
                              : Colors.grey,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _onNextPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6750A4),
                    ),
                    child: Text(
                      _currentPage == _images.length - 1
                          ? 'Get Started'
                          : 'Next',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 40),
                child: Text(
                  'Accessibility',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6750A4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}