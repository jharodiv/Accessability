// signup_form.dart - Add address field and geocoding
import 'dart:math';

import 'package:accessability/accessability/presentation/widgets/errorWidget/error_display_widget.dart';
import 'package:flutter/material.dart';
import 'package:accessability/accessability/logic/firebase_logic/sign_up_model.dart';
import 'package:accessability/accessability/presentation/screens/auth_screens/upload_profile_screen.dart';
import 'package:accessability/accessability/firebaseServices/place/geocoding_service.dart';

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
  final TextEditingController addressController =
      TextEditingController(); // NEW

  // Focus nodes to allow keyboard "Next" navigation
  late final List<FocusNode> _focusNodes;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isGeocoding = false; // NEW
  final TextEditingController captchaController =
      TextEditingController(); // NEW
  String? _selectedPwdType = 'Family'; // default value requested
  late int _captchaA; // captcha values
  late int _captchaB;

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(9, (_) => FocusNode());
    _generateCaptcha();
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
    addressController.dispose();
    captchaController.dispose();

    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _generateCaptcha() {
    final rnd = Random();
    _captchaA = rnd.nextInt(9) + 1; // 1..9
    _captchaB = rnd.nextInt(9) + 1; // 1..9
    captchaController.clear();
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

  // NEW: Geocode address to get coordinates
  Future<Map<String, double>?> _geocodeAddress(String address) async {
    if (address.isEmpty) return null;

    setState(() {
      _isGeocoding = true;
    });

    try {
      final geocodingService = OpenStreetMapGeocodingService();
      final coordinates =
          await geocodingService.getCoordinatesFromAddress(address);

      setState(() {
        _isGeocoding = false;
      });

      return coordinates;
    } catch (e) {
      setState(() {
        _isGeocoding = false;
      });
      print('Geocoding error: $e');
      return null;
    }
  }

  void signup() async {
    String username = usernameController.text.trim();
    String firstName = firstNameController.text.trim();
    String lastName = lastNameController.text.trim();
    String email = emailController.text.trim();
    String contact = contactNumberController.text.trim();
    String password = passwordController.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();
    String address = addressController.text.trim();
    String captchaInput = captchaController.text.trim();
    String pwdType = _selectedPwdType ?? '';

    // Check for empty fields
    if (username.isEmpty ||
        firstName.isEmpty ||
        lastName.isEmpty ||
        email.isEmpty ||
        contact.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        address.isEmpty ||
        captchaInput.isEmpty ||
        pwdType.isEmpty) {
      // NEW: Check address
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

    final expected = _captchaA + _captchaB;
    final parsed = int.tryParse(captchaInput);
    if (parsed == null || parsed != expected) {
      showDialog(
        context: context,
        builder: (context) => ErrorDisplayWidget(
          title: "Captcha Error",
          message: "Captcha answer is incorrect. Please try again.",
        ),
      );
      // regenerate captcha on wrong attempt
      setState(() {
        _generateCaptcha();
      });
      return;
    }

    // NEW: Geocode address
    final coordinates = await _geocodeAddress(address);
    if (coordinates == null) {
      showDialog(
        context: context,
        builder: (context) => ErrorDisplayWidget(
          title: "Address Error",
          message: "Could not find the address. Please check and try again.",
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
      address: address, // NEW
      latitude: coordinates['latitude']!, // NEW
      longitude: coordinates['longitude']!, // NEW
      pwdType: pwdType, // NEW
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

                // NEW: Address Field
                TextField(
                  controller: addressController,
                  focusNode: _focusNodes[5],
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _focusNodes[6].requestFocus(),
                  decoration: InputDecoration(
                    labelText: 'Home Address',
                    border: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 3.0),
                    ),
                    suffixIcon: _isGeocoding
                        ? const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.location_on, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 20),

                // Password
                TextField(
                  controller: passwordController,
                  focusNode: _focusNodes[6],
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _focusNodes[7].requestFocus(),
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
                  focusNode: _focusNodes[7],
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

// PWD Type Dropdown
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Type of Disability',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 3.0),
                    ),
                  ),
                  value: _selectedPwdType,
                  items: const [
                    DropdownMenuItem(
                        value: 'Family',
                        child: Text('Family')), // default value
                    DropdownMenuItem(
                        value: 'Visual Impairment',
                        child: Text('Visual Impairment')),
                    DropdownMenuItem(
                        value: 'Hearing Impairment',
                        child: Text('Hearing Impairment')),
                    DropdownMenuItem(
                        value: 'Speech Impairment',
                        child: Text('Speech Impairment')),
                    DropdownMenuItem(
                        value: 'Physical Disability',
                        child: Text('Physical Disability')),
                    DropdownMenuItem(
                        value: 'Intellectual Disability',
                        child: Text('Intellectual Disability')),
                    DropdownMenuItem(
                        value: 'Learning Disability',
                        child: Text('Learning Disability')),
                    DropdownMenuItem(
                        value: 'Psychosocial Disability',
                        child: Text('Psychosocial Disability')),
                    DropdownMenuItem(
                        value: 'Chronic Illness',
                        child: Text('Chronic Illness')),
                    DropdownMenuItem(
                        value: 'Multiple Disabilities',
                        child: Text('Multiple Disabilities')),
                    DropdownMenuItem(value: 'Others', child: Text('Others')),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedPwdType = value),
                ),
                const SizedBox(height: 16),

// Simple math captcha (A + B)
// --- Responsive, near-white captcha block (replace previous captcha block) ---

                LayoutBuilder(builder: (context, constraints) {
                  final bool isNarrow = constraints.maxWidth < 420;

                  Widget equationPill() {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey[50], // near-white
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        '$_captchaA  +  $_captchaB  =',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    );
                  }

                  Widget answerField({double? width}) {
                    return SizedBox(
                      width: width,
                      child: TextField(
                        controller: captchaController,
                        focusNode: _focusNodes[8],
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => signup(),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 12),
                          hintText: 'Answer',
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.grey[50], // input nearly white
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                      ),
                    );
                  }

                  Widget refreshButton() {
                    return Material(
                      color: Colors.transparent,
                      child: IconButton(
                        tooltip: 'Refresh captcha',
                        splashRadius: 22,
                        icon: const Icon(Icons.refresh),
                        color: const Color(0xFF6750A4),
                        onPressed: () => setState(() => _generateCaptcha()),
                      ),
                    );
                  }

                  // the card wrapper (near-white)
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white, // close to white
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withOpacity(0.02), // very subtle shadow
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: isNarrow
                        // stacked layout for small screens
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Human verification',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade900,
                                      ),
                                    ),
                                  ),
                                  refreshButton(),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Prove you are not a bot — solve the quick sum.',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  equationPill(),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child:
                                          answerField()), // expands on narrow screens
                                ],
                              ),
                            ],
                          )
                        // row layout for wider screens
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // left: label + description
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Human verification',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade900),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Prove you are not a bot — solve the quick sum.',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 12),

                              // equation pill
                              equationPill(),

                              const SizedBox(width: 12),

                              // answer input (fixed width)
                              answerField(width: 120),

                              const SizedBox(width: 8),

                              // refresh
                              refreshButton(),
                            ],
                          ),
                  );
                }),

                const SizedBox(height: 20),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: _isGeocoding ? null : signup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6750A4),
                    padding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 50),
                    textStyle: const TextStyle(fontSize: 20),
                  ),
                  child: _isGeocoding
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
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
