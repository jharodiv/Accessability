import 'package:accessability/accessability/presentation/widgets/errorWidget/error_display_widget.dart';
import 'package:flutter/material.dart';
import 'package:accessability/accessability/logic/firebase_logic/sign_up_model.dart';
import 'package:accessability/accessability/presentation/screens/auth_screens/upload_profile_screen.dart';
import 'package:accessability/accessability/presentation/screens/auth_screens/login_screen.dart';

class SignupForm extends StatefulWidget {
  const SignupForm({super.key});

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController contactNumberController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  // Focus nodes to allow keyboard "Next" navigation
  late final List<FocusNode> _focusNodes;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(7, (_) => FocusNode());
  }

  @override
  void dispose() {
    usernameController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    contactNumberController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();

    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  /// Unicode-aware validator: requires at least 2 letters and only allows
  /// letters, spaces, apostrophes and hyphens. Returns `null` if valid,
  /// otherwise returns the error message.
  String? improvedUnicodeNameValidator(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Please enter your name';

    // Count actual letters (Unicode-aware)
    final letterMatches = RegExp(r'\p{L}', unicode: true).allMatches(v);
    if (letterMatches.length < 2) {
      return 'Please enter at least 2 letters';
    }

    // Ensure the whole string contains only allowed characters:
    // letters, spaces, apostrophes and hyphens
    final allowed = RegExp(r"^[\p{L}\s'-]+$", unicode: true);
    if (!allowed.hasMatch(v)) {
      return 'Only letters, spaces, apostrophes and hyphens allowed';
    }

    return null; // valid
  }

  void signup() {
    String username = usernameController.text.trim();
    String firstName = firstNameController.text.trim();
    String lastName = lastNameController.text.trim();
    String email = emailController.text.trim();
    String contact = contactNumberController.text.trim();
    String password = passwordController.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();

    // Check for empty fields
    if (username.isEmpty ||
        firstName.isEmpty ||
        lastName.isEmpty ||
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

    // First name: use improved Unicode-aware validator
    final firstNameError = improvedUnicodeNameValidator(firstName);
    if (firstNameError != null) {
      showDialog(
        context: context,
        builder: (context) => ErrorDisplayWidget(
          title: "Invalid First Name",
          message: firstNameError,
        ),
      );
      return;
    }

    // Last name: use improved Unicode-aware validator
    final lastNameError = improvedUnicodeNameValidator(lastName);
    if (lastNameError != null) {
      showDialog(
        context: context,
        builder: (context) => ErrorDisplayWidget(
          title: "Invalid Last Name",
          message: lastNameError,
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
      firstName: firstName,
      lastName: lastName,
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
    // Back to original visual design and spacing (no visible Next/DONE button)
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

                // Username
                TextField(
                  controller: usernameController,
                  focusNode: _focusNodes[0],
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _focusNodes[1].requestFocus(),
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 3.0),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // First Name
                TextField(
                  controller: firstNameController,
                  focusNode: _focusNodes[1],
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _focusNodes[2].requestFocus(),
                  decoration: const InputDecoration(
                    labelText: 'First Name',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 3.0),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Last Name
                TextField(
                  controller: lastNameController,
                  focusNode: _focusNodes[2],
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _focusNodes[3].requestFocus(),
                  decoration: const InputDecoration(
                    labelText: 'Last Name',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 3.0),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Email
                TextField(
                  controller: emailController,
                  focusNode: _focusNodes[3],
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _focusNodes[4].requestFocus(),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 3.0),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Contact Number
                TextField(
                  controller: contactNumberController,
                  focusNode: _focusNodes[4],
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _focusNodes[5].requestFocus(),
                  decoration: const InputDecoration(
                    labelText: 'Contact Number',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 3.0),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Password
                TextField(
                  controller: passwordController,
                  focusNode: _focusNodes[5],
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _focusNodes[6].requestFocus(),
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

                // Confirm Password (last)
                TextField(
                  controller: confirmPasswordController,
                  focusNode: _focusNodes[6],
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => signup(),
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
                const SizedBox(height: 15),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account? "),
                    GestureDetector(
                      onTap: () {
                        // if you want to pop back to a previous LoginScreen:
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        "Login",
                        style: TextStyle(
                          color: Color(0xFF6750A4),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
