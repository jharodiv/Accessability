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

  // if user dictates, we'll show live transcription here
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
      // Complete the onboarding process using BLoC (if needed)
      // context.read<AuthBloc>().add(CompleteOnboardingEvent());
      Navigator.of(context).pushReplacementNamed(
        '/homescreen',
        arguments: {'showTutorial': true},
      );
    }
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      // optionally show a message or reinitialize
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

    // start listening
    await _speechService.startListening(
      onResult: (text) {
        // update live transcription for the current page
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

  Widget _buildIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_images.length, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                index == _currentPage ? const Color(0xFF6750A4) : Colors.grey,
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Disable back button
        return false;
      },
      child: Scaffold(
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
                              // description (or live transcription while listening)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0),
                                child: Text(
                                  description,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.black,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // mic + speaker row (centered)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Speaker (TTS)
                                  IconButton(
                                    onPressed: _speakCurrentDescription,
                                    iconSize: 28,
                                    icon: const Icon(Icons.volume_up_outlined),
                                    color: const Color(0xFF6750A4),
                                    tooltip: 'Read aloud',
                                  ),

                                  const SizedBox(width: 10),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildIndicators(),
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
                    const SizedBox(height: 16),
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
      ),
    );
  }
}
