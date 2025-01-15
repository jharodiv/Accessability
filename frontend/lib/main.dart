import 'package:flutter/material.dart';
import 'package:frontend/accessability/presentation/screens/splash_screen.dart';
import 'package:frontend/accessability/router/app_router.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final AppRouter _appRouter = AppRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/onboarding', // Set your initial route here
      onGenerateRoute:
          _appRouter.onGenerateRoute, // Use the AppRouter for route generation
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white, // Set white background globally
      ),
    );
  }
}
