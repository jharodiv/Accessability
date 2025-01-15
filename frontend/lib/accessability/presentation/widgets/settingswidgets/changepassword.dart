import 'package:flutter/material.dart';
import 'package:frontend/accessability/presentation/screens/authscreens/forgotpasswordscreen.dart';
import 'package:frontend/accessability/presentation/widgets/settingswidgets/accountscreen.dart';

class Changepassword extends StatefulWidget {
  const Changepassword({super.key});

  @override
  _ChangepasswordState createState() => _ChangepasswordState();
}

class _ChangepasswordState extends State<Changepassword> {
  bool isPasswordVisible = false;
  bool isNewPasswordVisible = false;
  bool isRetypePasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context,
                MaterialPageRoute(builder: (context) => const AccountScreen()));
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text(
          'Change Password',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 2,
        shadowColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              obscureText: !isPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Current Password',
                border: const UnderlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      isPasswordVisible = !isPasswordVisible;
                    });
                  },
                  icon: Icon(isPasswordVisible
                      ? Icons.visibility
                      : Icons.visibility_off),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              obscureText: !isNewPasswordVisible,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: const UnderlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      isNewPasswordVisible = !isNewPasswordVisible;
                    });
                  },
                  icon: Icon(isNewPasswordVisible
                      ? Icons.visibility
                      : Icons.visibility_off),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              obscureText: !isRetypePasswordVisible,
              decoration: InputDecoration(
                labelText: 'Re-type New Password',
                border: const UnderlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      isRetypePasswordVisible = !isRetypePasswordVisible;
                    });
                  },
                  icon: Icon(isRetypePasswordVisible
                      ? Icons.visibility
                      : Icons.visibility_off),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Your new password must have:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'At least 8 characters \n\n1 letter and 1 number \n\n1 Special Character',
              style: TextStyle(fontSize: 14, color: Colors.black),
            ),
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  SizedBox(
                    width: 120,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6750A4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const ForgotPasswordScreen()));
                    },
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: Color(0xFF6750A4),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
