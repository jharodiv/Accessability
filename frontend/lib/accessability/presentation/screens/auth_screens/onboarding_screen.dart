// onboarding_with_speech.dart
import 'package:flutter/material.dart';
import 'package:accessability/accessability/logic/bloc/auth/auth_bloc.dart';
import 'package:accessability/accessability/logic/bloc/auth/auth_event.dart';
import 'package:accessability/accessability/presentation/screens/chat_system/speech_service.dart'; // your service file
// other imports...

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

  final SpeechService _speechService = SpeechService();
  final Map<int, String> _liveTranscription = {};

  bool _isListening = false;
  bool _speechAvailable = false;

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

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speechService.initializeSpeech();
    if (mounted) setState(() {});
  }

  void _onNextPressed() {
    if (_currentPage < _images.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    } else {
      Navigator.of(context).pushReplacementNamed(
        '/homescreen',
        arguments: {'showTutorial': true},
      );
    }
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available')),
      );
      return;
    }

    if (_isListening) {
      await _speechService.stopListening();
      setState(() => _isListening = false);
      return;
    }

    await _speechService.startListening(
      onResult: (text) {
        if (mounted) {
          setState(() {
            _liveTranscription[_currentPage] = text;
          });
        }
      },
      onListeningStarted: () {
        if (mounted) setState(() => _isListening = true);
      },
      onListeningStopped: () {
        if (mounted) setState(() => _isListening = false);
      },
    );
  }

  void _speakCurrentDescription() {
    final text = _descriptions[_currentPage];
    _speechService.speakText(text);
  }

  @override
  void dispose() {
    _speechService.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildIndicators(Color activeColor, Color inactiveColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_images.length, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index == _currentPage ? activeColor : inactiveColor,
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white.withOpacity(0.9) : Colors.black;
    final headingColor =
        isDark ? const Color(0xFFD0BCFF) : const Color(0xFF6750A4);
    final indicatorActive = const Color(0xFF6750A4);
    final indicatorInactive = isDark ? Colors.white30 : Colors.grey.shade400;
    final buttonColor = const Color(0xFF6750A4);

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: backgroundColor,
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
                          final description =
                              _liveTranscription[index]?.isNotEmpty == true
                                  ? _liveTranscription[index]!
                                  : _descriptions[index];

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                _images[index],
                                height: 300,
                                fit: BoxFit.cover,
                              ),
                              const SizedBox(height: 20),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0),
                                child: Text(
                                  description,
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: textColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: _speakCurrentDescription,
                                    iconSize: 28,
                                    icon: const Icon(Icons.volume_up_outlined),
                                    color: buttonColor,
                                    tooltip: 'Read aloud',
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildIndicators(indicatorActive, indicatorInactive),
                    const SizedBox(height: 20),
                    Semantics(
                      label: 'Next',
                      button: true, // 👈 important, tells Flutter it’s a button

                      child: ElevatedButton(
                        onPressed: _onNextPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                        child: Text(
                          _currentPage == _images.length - 1
                              ? 'Get Started'
                              : 'Next',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Text(
                    'Accessibility',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: headingColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
