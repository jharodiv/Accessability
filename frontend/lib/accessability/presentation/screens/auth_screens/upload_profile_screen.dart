import 'dart:io';
import 'package:AccessAbility/accessability/presentation/screens/auth_screens/verify_email_screen.dart';
import 'package:AccessAbility/accessability/presentation/widgets/errorWidget/error_display_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_state.dart';
import 'package:AccessAbility/accessability/logic/firebase_logic/sign_up_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_event.dart';

class UploadProfileScreen extends StatefulWidget {
  final SignUpModel signUpModel;

  const UploadProfileScreen({
    super.key,
    required this.signUpModel,
  });

  @override
  State<UploadProfileScreen> createState() => _UploadProfileScreenState();
}

class _UploadProfileScreenState extends State<UploadProfileScreen> {
  XFile? _imageFile;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _imageFile = pickedFile;
    });
  }

  void _finishSignup() {
    final authBloc = BlocProvider.of<AuthBloc>(context);
    authBloc.add(
      RegisterEvent(
        signUpModel: widget.signUpModel,
        profilePicture: _imageFile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is RegistrationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "Successfully signed up, you can verify your email now!"),
              backgroundColor: Colors.lightGreen,
            ),
          );

          // Get the current user
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            // Navigate to the verification screen and pass the user
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => VerifyEmailScreen(user: user),
              ),
            );
          }
        } else if (state is AuthError) {
          showDialog(
            context: context,
            builder: (context) => ErrorDisplayWidget(
              title: "Signup Error",
              message: state.message,
            ),
          );
        }
      },
      child: Scaffold(
        body: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is AuthLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
            return Column(
              children: [
                SafeArea(
                  child: Container(
                    padding: const EdgeInsets.all(20.0),
                    alignment: Alignment.center,
                    child: const Text(
                      "ACCESSABILITY",
                      style: TextStyle(
                        fontSize: 24, // Adjust font size as needed
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6750A4),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Please upload your profile picture",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            radius: 70,
                            backgroundColor: const Color(0xFF6750A4),
                            backgroundImage: _imageFile != null
                                ? FileImage(File(_imageFile!.path))
                                : null,
                            child: _imageFile == null
                                ? const Icon(Icons.person,
                                    size: 70, color: Colors.white)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _pickImage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6750A4),
                            minimumSize: const Size(250, 60),
                          ),
                          child: const Text("Upload Picture"),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed:
                            state is AuthLoading ? null : () => _finishSignup(),
                        child: const Text(
                          "Skip",
                          style: TextStyle(
                            color: Color(0xFF6750A4),
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed:
                            state is AuthLoading ? null : () => _finishSignup(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6750A4),
                          minimumSize: const Size(100, 40),
                        ),
                        child: const Text("Finish"),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
