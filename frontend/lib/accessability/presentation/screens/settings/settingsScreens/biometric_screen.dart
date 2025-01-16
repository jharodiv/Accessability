import 'package:flutter/material.dart';

class Biometriclogin extends StatefulWidget {
  const Biometriclogin({super.key});

  @override
  _BiometricloginState createState() => _BiometricloginState();
}

class _BiometricloginState extends State<Biometriclogin> {
  bool isBiometricEnabled = true;

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
        centerTitle: true,
        elevation: 2,
        shadowColor: Colors.black,
      ),
      body: Stack(
        children: [
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'assets/images/settings/biometric_login.png',
                width: 350,
                height: 350,
              ),
            ),
          ),
          const Positioned(
            top: 320,
            left: 0,
            right: 0,
            child: Text(
              'Biometric Login',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          const Positioned(
            top: 350,
            left: 0,
            right: 0,
            child: Text(
              'Sign in to your account faster using Biometrics \n login',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          Positioned(
            top: 440,
            left: 0,
            right: 0,
            child: ListTile(
              title: const Text(
                'Enable Biometric Login',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              trailing: Switch(
                value: isBiometricEnabled,
                onChanged: (bool value) {
                  setState(() {
                    isBiometricEnabled = value; // Toggle the switch state
                  });
                },
              ),
            ),
          ),
          // Text below the screen
          const Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Center(
                child: Text(
                  'By enabling biometrics login, you will allow Accessability to access your saved biometrics data in your device to create and save data in Accessability that shall be used for securing your login. The data will no be used for any other purposes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.black54,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
