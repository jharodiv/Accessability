import 'package:flutter/material.dart';
import 'package:frontend/accessability/presentation/screens/authScreens/signup_screen.dart';
import 'package:frontend/accessability/presentation/screens/authScreens/onboarding_screen.dart';
import 'package:frontend/accessability/presentation/screens/gpsScreen/gps.dart';
import 'package:frontend/accessability/presentation/widgets/authWidgets/login_form.dart';

class AppRouter {
  Route<dynamic>? onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case '/':
        return _buildRoute(const SignupScreen(), clearStack: true);
      case SignupScreen.routeName:
        return _buildRoute(const SignupScreen());
      case '/login':
        return _buildRoute(const Loginform(), clearStack: true);
      case '/onboarding':
        return _buildRoute(const OnboardingScreen(), clearStack: true);
      case '/homescreen':
        return _buildRoute(const GpsScreen(), clearStack: true);
    }
    return null; // Handle unknown routes
  }

  MaterialPageRoute _buildRoute(Widget child, {bool clearStack = false}) {
    return MaterialPageRoute(
      builder: (context) {
        if (clearStack) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => child),
              (route) => false,
            );
          });
          return const SizedBox.shrink();
        }
        return child;
      },
    );
  }
}
