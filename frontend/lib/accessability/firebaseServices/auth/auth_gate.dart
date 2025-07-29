import 'package:AccessAbility/accessability/logic/bloc/auth/auth_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_event.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_state.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_event.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_state.dart';
import 'package:AccessAbility/accessability/presentation/screens/authscreens/login_screen.dart';
import 'package:AccessAbility/accessability/presentation/screens/gpsscreen/gps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authBloc = context.read<AuthBloc>();
    final userBloc = context.read<UserBloc>();
    authBloc.add(CheckAuthStatus());

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is AuthLoading) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                strokeWidth: 3,
              ),
            ),
          );
        } else if (authState is AuthenticatedLogin) {
          userBloc.add(FetchUserData());
          return BlocBuilder<UserBloc, UserState>(
            builder: (context, userState) {
              if (userState is UserLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (userState is UserLoaded) {
                return const GpsScreen();
              } else {
                // Fall back to LoginScreen if user data fails
                return const LoginScreen();
              }
            },
          );
        } else {
          // For AuthError, AuthInitial, or any other state → Show LoginScreen
          return const LoginScreen();
        }
      },
    );
  }
}
