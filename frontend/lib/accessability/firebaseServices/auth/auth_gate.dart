import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:Accessability/accessability/logic/bloc/auth/auth_bloc.dart';
import 'package:Accessability/accessability/logic/bloc/auth/auth_event.dart';
import 'package:Accessability/accessability/logic/bloc/auth/auth_state.dart';
import 'package:Accessability/accessability/logic/bloc/user/user_bloc.dart';
import 'package:Accessability/accessability/logic/bloc/user/user_event.dart';
import 'package:Accessability/accessability/logic/bloc/user/user_state.dart';
import 'package:Accessability/accessability/presentation/screens/authScreens/login_screen.dart';
import 'package:Accessability/accessability/presentation/screens/gpsScreen/gps.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Access the already provided AuthBloc and UserBloc
    final authBloc = context.read<AuthBloc>();
    final userBloc = context.read<UserBloc>();

    // Check authentication status when AuthGate is built
    authBloc.add(CheckAuthStatus());

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is AuthLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (authState is AuthenticatedLogin) {
          // Fetch user data when authenticated
          userBloc.add(FetchUserData());

          // Wait for UserBloc to emit UserLoaded
          return BlocBuilder<UserBloc, UserState>(
            builder: (context, userState) {
              if (userState is UserLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (userState is UserLoaded) {
                // Navigate to GpsScreen with user data
                return const GpsScreen();
              } else if (userState is UserError) {
                return Center(child: Text(userState.message));
              } else {
                return const Center(child: Text('No user data available'));
              }
            },
          );
        } else if (authState is AuthInitial) {
          // Navigate to LoginScreen if not authenticated
          return const LoginScreen();
        } else if (authState is AuthError) {
          return Center(child: Text(authState.message));
        } else {
          return const Center(child: Text('Something went wrong'));
        }
      },
    );
  }
}