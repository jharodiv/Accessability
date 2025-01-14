import 'package:flutter/material.dart';

class Biometriclogin extends StatelessWidget {
  const Biometriclogin({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading:
            IconButton(onPressed: () {}, icon: const Icon(Icons.arrow_back)),
        title: const Text(
          'Biometric Login',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: const Center(
        child: Text('Biometric Login'),
      ),
    );
  }
}
