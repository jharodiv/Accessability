import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:AccessAbility/accessability/firebaseServices/auth/auth_gate.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:AccessAbility/accessability/themes/theme_provider.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Access the ThemeProvider to determine the current theme
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDarkMode = themeProvider.isDarkMode;

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
      backgroundColor: isDarkMode ? Colors.black : Colors.white, // Set background color based on theme
    );
  }
}