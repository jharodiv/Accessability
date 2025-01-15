import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:frontend/accessability/presentation/screens/authscreens/signupscreen.dart';
import 'package:lottie/lottie.dart';

class Splashscreen extends StatelessWidget {
  const Splashscreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedSplashScreen(
      splash: Center(
        child: SizedBox(
          height: 200,
          child: OverflowBox(
            minHeight: 150,
            maxHeight: 150,
            child: Lottie.asset(
              'assets/animation/Animation - 1735294254709.json',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
      nextScreen: SignupScreen(),
      duration: 3500,
    );
  }
}
