import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class BiometricLogin extends StatefulWidget {
  const BiometricLogin({super.key});

  @override
  _BiometricLoginState createState() => _BiometricLoginState();
}

class _BiometricLoginState extends State<BiometricLogin> {
  late final LocalAuthentication _localAuth;
  bool isBiometricEnabled = true;
  bool _supportState = false;

  @override
  void initState() {
    super.initState();
    _localAuth = LocalAuthentication();
    _localAuth.isDeviceSupported().then(
          (bool isSupported) => setState(
            () {
              _supportState = isSupported;
            },
          ),
        );
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      bool isAvailable = await _localAuth.canCheckBiometrics;
      bool didAuthenticate = false;

      if (isAvailable) {
        didAuthenticate = await _localAuth.authenticate(
          localizedReason: 'Authenticate to login',
          options: const AuthenticationOptions(
            biometricOnly: true,
            useErrorDialogs: true,
            stickyAuth: true,
          ),
        );

        if (didAuthenticate) {
          // Handle successful authentication
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Authentication successful!')),
          );
          // Navigate to the next screen or perform login
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Biometric authentication not available')),
        );
      }
    } catch (e) {
      print('Error using biometrics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white, // Set the AppBar background color
            boxShadow: [
              BoxShadow(
                color: Colors.black26, // Shadow color
                offset: Offset(0, 1), // Horizontal and Vertical offset
                blurRadius: 2, // How much to blur the shadow
              ),
            ],
          ),
          child: AppBar(
            elevation: 0, // Remove default elevation
            leading: IconButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.arrow_back),
              color: const Color(0xFF6750A4),
            ),
            title: const Text(
              'Biometric Login',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
          ),
        ),
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
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          const Positioned(
            top: 350,
            left: 0,
            right: 0,
            child: Padding(
              padding: EdgeInsets.only(top: 8),
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
          ),
          Positioned(
            top: 440,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 8),
              child: ListTile(
                title: const Text(
                  'Enable Biometric Login',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                trailing: Switch(
                  value: isBiometricEnabled,
                  onChanged: (bool value) {
                    setState(() {
                      isBiometricEnabled = value; // Toggle the switch state
                    });
                  },
                  activeColor:
                      const Color(0xFF6750A4), // Set the active color to purple
                ),
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
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'By enabling biometrics login, you will allow Accessability to access your saved biometrics data in your device to create and save data in Accessability that shall be used for securing your login. The data will not be used for any other purposes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _getAvaialbleBiometrics() async {
    List<BiometricType> availableBiometrics =
        await _localAuth.getAvailableBiometrics();
    print("List of avaialbleBiometrics:  $availableBiometrics");

    if (!mounted) {
      return;
    }
  }
}
