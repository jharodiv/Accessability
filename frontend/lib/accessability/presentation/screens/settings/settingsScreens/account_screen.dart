import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/accessability/logic/bloc/user/user_bloc.dart';
import 'package:frontend/accessability/logic/bloc/user/user_state.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserBloc, UserState>(
      builder: (context, state) {
        if (state is UserLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is UserError) {
          return Center(child: Text(state.message));
        } else if (state is UserLoaded) {
          final user = state.user;
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
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: user.profilePicture.isNotEmpty
                                ? NetworkImage(user.profilePicture)
                                : null,
                            child: user.profilePicture.isEmpty
                                ? Text(
                                    user.username[0].toUpperCase(),
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            user.username,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(
                              height:
                                  4), // Add some space between the username and the divider
                          Container(
                            width: 150, // Set the width of the divider
                            height: 1, // Set the height of the divider
                            color: Colors
                                .grey[400], // Set the color of the divider
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double
                        .infinity, // Make the container take the full width

                    color: const Color(
                        0xFFF0F0F0), // Set background color to F0F0F0
                    padding:
                        const EdgeInsets.all(8.0), // Optional: Add some padding
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Text(
                        'Account Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF919191), // Set text color to 919191
                        ),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.phone_outlined,
                        color: Color(0xFF6750A4)),
                    title: const Text('Phone Number'), // Title remains normal
                    subtitle: Text(
                      user.contactNumber ?? 'Not provided',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold), // Make subtitle bold
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.email_outlined,
                        color: Color(0xFF6750A4)),
                    title: const Text('Email Address'), // Title remains normal
                    subtitle: Text(
                      user.email,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold), // Make subtitle bold
                    ),
                  ),
                  const Divider(),
                  const ListTile(
                    leading: Icon(Icons.lock_outline, color: Color(0xFF6750A4)),
                    title: Text('Password'), // Title remains normal
                    subtitle: Text(
                      '***********',
                      style: TextStyle(
                          fontWeight: FontWeight.bold), // Make subtitle bold
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double
                        .infinity, // Make the container take the full width

                    color: const Color(
                        0xFFF0F0F0), // Set background color to F0F0F0
                    padding:
                        const EdgeInsets.all(8.0), // Optional: Add some padding
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text(
                        'Account Management',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF919191), // Set text color to 919191
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
                          side: const BorderSide(
                              color: Color(0xFF6750A4)), // Set border color
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(50), // Set border radius
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF6750A4), // Set background color
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(50), // Set border radius
                          ),
                        ),
                        child: const Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: const Text('Save'),
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
    );
  }
}
