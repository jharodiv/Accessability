import 'package:AccessAbility/accessability/presentation/widgets/errorWidget/error_display_widget.dart';
import 'package:flutter/material.dart';
import 'package:AccessAbility/accessability/logic/firebase_logic/SignupModel.dart';
import 'package:AccessAbility/accessability/presentation/screens/authScreens/upload_profile_screen.dart';

class SignupForm extends StatefulWidget {
  const SignupForm({super.key});

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController contactNumberController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  String? errorTitle;
  String? errorMessage;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    usernameController.dispose();
    emailController.dispose();
    contactNumberController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void signup() {
    String username = usernameController.text.trim();
    String email = emailController.text.trim();
    String contact = contactNumberController.text.trim();
    String password = passwordController.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();

    // Check for empty fields
    if (username.isEmpty ||
        email.isEmpty ||
        contact.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => ErrorDisplayWidget(
          title: "Missing Fields",
          message: "Please fill in all fields.",
        ),
      );
      return;
    }

    // Username must be at least 6 characters
    if (username.length < 6) {
      showDialog(
        context: context,
        builder: (context) => ErrorDisplayWidget(
          title: "Invalid Username",
          message: "Username must be at least 6 characters long.",
        ),
      );
      return;
    }

    // Basic email validation
    bool isEmailValid =
        RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$").hasMatch(email);
    if (!isEmailValid) {
      showDialog(
        context: context,
        builder: (context) => ErrorDisplayWidget(
          title: "Invalid Email",
          message: "Please enter a valid email address.",
        ),
      );
      return;
    }

    // Contact must be numeric
    if (!RegExp(r'^\d{11,}$').hasMatch(contact)) {
      showDialog(
        context: context,
        builder: (context) => ErrorDisplayWidget(
          title: "Invalid Contact Number",
          message:
              "Contact number must contain only digits and be at least 11 digits long.",
        ),
      );
      return;
    }

    // Password must be at least 8 characters
    if (password.length < 8) {
      showDialog(
        context: context,
        builder: (context) => ErrorDisplayWidget(
          title: "Weak Password",
          message: "Password must be at least 8 characters long.",
        ),
      );
      return;
    }

    // Password match check
    if (password != confirmPassword) {
      showDialog(
        context: context,
        builder: (context) => ErrorDisplayWidget(
          title: "Password Mismatch",
          message: "Passwords do not match.",
        ),
      );
      return;
    }

    // If all validations pass, navigate to the next screen
    final signUpModel = SignUpModel(
      username: username,
      email: email,
      password: password,
      contactNumber: contact,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UploadProfileScreen(
          signUpModel: signUpModel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Sign Up',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 30,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 3.0),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 3.0),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: contactNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Contact Number',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 3.0),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 3.0),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    border: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 3.0),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: signup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6750A4),
                    padding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 50),
                    textStyle: const TextStyle(fontSize: 20),
                  ),
                  child: const Text(
                    'SIGN UP',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
