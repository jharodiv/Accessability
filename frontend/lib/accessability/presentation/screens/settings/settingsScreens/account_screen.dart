import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/accessability/logic/bloc/user/user_bloc.dart';
import 'package:frontend/accessability/logic/bloc/user/user_event.dart';
import 'package:frontend/accessability/logic/bloc/user/user_state.dart';
import 'package:image_picker/image_picker.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  XFile? _imageFile;
  bool _isUpdatingProfilePicture = false; // Track if profile picture is being updated

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    // Check if the widget is still mounted
    if (!mounted) return;

    setState(() {
      _imageFile = pickedFile;
    });

    if (_imageFile != null) {
      // Check if the widget is still mounted
      if (!mounted) return;

      setState(() {
        _isUpdatingProfilePicture = true; // Show loading indicator
      });

      final userBloc = context.read<UserBloc>();
      final userState = userBloc.state;

      if (userState is UserLoaded) {
        print('Dispatching UploadProfilePictureEvent...');
        userBloc.add(
          UploadProfilePictureEvent(
            uid: userState.user.uid,
            profilePicture: _imageFile!,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UserBloc, UserState>(
      listener: (context, state) {
        if (state is UserLoaded) {
          print('Profile picture updated successfully');
          setState(() {
            _isUpdatingProfilePicture = false; // Hide loading indicator
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (state is UserError) {
          print('Profile picture update error: ${state.message}');
          setState(() {
            _isUpdatingProfilePicture = false; // Hide loading indicator
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${state.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: BlocBuilder<UserBloc, UserState>(
        builder: (context, state) {
          if (state is UserLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is UserError) {
            return Center(child: Text(state.message));
          } else if (state is UserLoaded) {
            final user = state.user;

            // Show loading indicator while updating profile picture
            if (_isUpdatingProfilePicture) {
              print('Profile picture updating...');
              return const Center(child: CircularProgressIndicator());
            }

            return Scaffold(
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(65),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        offset: Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  child: AppBar(
                    elevation: 0,
                    leading: IconButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.arrow_back),
                      color: const Color(0xFF6750A4),
                    ),
                    title: const Text(
                      'Account',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    centerTitle: true,
                  ),
                ),
              ),
              body: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickImage,
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.grey[300],
                                backgroundImage: _imageFile != null
                                    ? FileImage(File(_imageFile!.path))
                                    : user.profilePicture.isNotEmpty
                                        ? NetworkImage(user.profilePicture)
                                        : null,
                                child: _imageFile == null && user.profilePicture.isEmpty
                                    ? Text(
                                        user.username[0].toUpperCase(),
                                        style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              user.username,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 150,
                              height: 1,
                              color: Colors.grey[400],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      color: const Color(0xFFF0F0F0),
                      padding: const EdgeInsets.all(8.0),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Text(
                          'Account Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF919191),
                          ),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.phone_outlined,
                          color: Color(0xFF6750A4)),
                      title: const Text('Phone Number'),
                      subtitle: Text(
                        user.contactNumber ?? 'Not provided',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.email_outlined,
                          color: Color(0xFF6750A4)),
                      title: const Text('Email Address'),
                      subtitle: Text(
                        user.email,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(),
                    const ListTile(
                      leading: Icon(Icons.lock_outline, color: Color(0xFF6750A4)),
                      title: Text('Password'),
                      subtitle: Text(
                        '***********',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      color: const Color(0xFFF0F0F0),
                      padding: const EdgeInsets.all(8.0),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Text(
                          'Account Management',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF919191),
                          ),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete, color: Colors.redAccent),
                      title: const Text(
                        'Delete Account',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                      onTap: () {},
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF6750A4)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            // Save other changes if needed
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6750A4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          } else {
            return const Center(child: Text('No user data available'));
          }
        },
      ),
    );
  }
}