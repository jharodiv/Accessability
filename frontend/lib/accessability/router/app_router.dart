import 'package:flutter/material.dart';
import 'package:frontend/accessability/presentation/screens/authscreens/signupscreen.dart';
import 'package:frontend/accessability/presentation/screens/authscreens/onboarding_screen.dart';
import 'package:frontend/accessability/presentation/widgets/authwidgets/loginform.dart';

class AppRouter {
  Route<dynamic>? onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case '/':
        return _buildRoute(const SignupScreen(), clearStack: true);
      case SignupScreen.routeName: // Use the routeName defined in SignupScreen
        return _buildRoute(const SignupScreen());
      case '/login':
        return _buildRoute(const Loginform(), clearStack: true);
      case '/onboarding':
        return _buildRoute(const OnboardingScreen(), clearStack: true);
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
