import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:frontend/accessability/presentation/screens/authScreens/login_screen.dart';
import 'package:frontend/accessability/presentation/screens/gpsScreen/gps.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return const GpsScreen();
            } else {
              return const LoginScreen();
            }
          }),
    );
  }
}
