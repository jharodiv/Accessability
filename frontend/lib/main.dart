import 'package:flutter/material.dart';
import 'package:frontend/accessability/presentation/screens/splashscreen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const Splashscreen(),
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white, // Set white background globally
      ),
    ),
  );
}
