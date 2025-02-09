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
            appBar: AppBar(
              title: const Text('Account'),
            ),
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          const CircleAvatar(
                            radius: 50,
                            backgroundImage:
                                AssetImage('assets/images/others/profile.jpg'),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            user.username,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Account Details',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6750A4)),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.person, color: Color(0xFF6750A4)),
                      title: const Text('Username'),
                      subtitle: Text(user.username),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, color: Color(0xFF6750A4)),
                        onPressed: () {},
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.email, color: Color(0xFF6750A4)),
                      title: const Text('Email'),
                      subtitle: Text(user.email),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, color: Color(0xFF6750A4)),
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
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