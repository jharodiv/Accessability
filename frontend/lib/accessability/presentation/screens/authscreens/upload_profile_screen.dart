import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/accessability/logic/bloc/auth/auth_state.dart';
import 'package:frontend/accessability/logic/firebase_logic/SignupModel.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend/accessability/logic/bloc/auth/auth_bloc.dart';
import 'package:frontend/accessability/logic/bloc/auth/auth_event.dart';

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
            SnackBar(
              content: const Text("Successfully signed up!"),
              backgroundColor: Colors.lightGreen,
            ),
          );
          // Navigate back to the login screen after successful registration
          Navigator.of(context).pushReplacementNamed('/login');
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: ${state.message}")),
          );
        }
      },
      child: Scaffold(
        body: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is AuthLoading) {
              // Show a loading indicator
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            radius: 50,
                            backgroundImage: _imageFile != null
                                ? FileImage(File(_imageFile!.path))
                                : null,
                            child: _imageFile == null
                                ? const Icon(Icons.person, size: 50)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _pickImage,
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
                        onPressed: state is AuthLoading ? null : () => _finishSignup(),
                        child: const Text("Skip"),
                      ),
                      ElevatedButton(
                        onPressed: state is AuthLoading ? null : () => _finishSignup(),
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