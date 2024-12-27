import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:frontend/accessability/screens/authscreens/signupscreen.dart';
import 'package:lottie/lottie.dart';

class Splashscreen extends StatelessWidget {
  const Splashscreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedSplashScreen(
      splash: Center(
        child: FractionallySizedBox(
          widthFactor: 0.8,
          child: Lottie.asset(
            'assets/animation/Animation - 1735294254709.json',
            fit: BoxFit.contain,
          ),
        ),
      ),
      nextScreen: SignupScreen(),
      duration: 3500,
    );
  }
}
