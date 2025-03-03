import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class FingerprintEnrollmentScreen extends StatefulWidget {
  const FingerprintEnrollmentScreen({super.key});

  @override
  _FingerprintEnrollmentScreenState createState() =>
      _FingerprintEnrollmentScreenState();
}

class _FingerprintEnrollmentScreenState
    extends State<FingerprintEnrollmentScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isEnrolling = false;

  Future<void> _enrollFingerprint() async {
    setState(() {
      _isEnrolling = true;
    });

    final didAuthenticate = await _localAuth.authenticate(
      localizedReason: 'Authenticate to enroll fingerprint',
      options: const AuthenticationOptions(
        biometricOnly: true,
        useErrorDialogs: true,
        stickyAuth: true,
      ),
    );

    setState(() {
      _isEnrolling = false;
    });

    Navigator.pop(context, didAuthenticate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enroll Fingerprint'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.fingerprint,
              size: 100,
              color: Color(0xFF6750A4),
            ),
            const SizedBox(height: 20),
            const Text(
              'Place your finger on the sensor to enroll',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            _isEnrolling
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _enrollFingerprint,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6750A4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 15),
                    ),
                    child: const Text(
                      'Enroll Fingerprint',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}