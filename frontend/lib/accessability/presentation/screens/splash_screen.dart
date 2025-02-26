import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:Accessability/accessability/firebaseServices/auth/auth_gate.dart';
import 'package:lottie/lottie.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

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
      nextScreen: const AuthGate(), // Navigate to AuthGate after splash
      duration: 3500,
    );
  }
}