import 'package:accessability/accessability/logic/bloc/auth/auth_bloc.dart';
import 'package:accessability/accessability/logic/bloc/auth/auth_event.dart';
import 'package:accessability/accessability/logic/bloc/auth/auth_state.dart';
import 'package:accessability/accessability/logic/bloc/user/user_bloc.dart';
import 'package:accessability/accessability/logic/bloc/user/user_event.dart';
import 'package:accessability/accessability/logic/bloc/user/user_state.dart';
import 'package:accessability/accessability/presentation/screens/auth_screens/login_screen.dart';
import 'package:accessability/accessability/presentation/screens/gpsscreen/gps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';

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
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: SizedBox(
                height: 200,
                child: OverflowBox(
                  minHeight: 150,
                  maxHeight: 150,
                  child: Lottie.asset(
                    'assets/animation/Animation - 1735294254709.json',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          );
        } else if (authState is AuthenticatedLogin) {
          userBloc.add(FetchUserData());
          return BlocBuilder<UserBloc, UserState>(
            builder: (context, userState) {
              if (userState is UserLoading) {
                return Scaffold(
                  backgroundColor: Colors.white,
                  body: Center(
                    child: Lottie.asset(
                      'assets/animations/gps_loading.json',
                      width: 180,
                      height: 180,
                      repeat: true,
                    ),
                  ),
                );
              } else if (userState is UserLoaded) {
                return const GpsScreen();
              } else {
                return const LoginScreen();
              }
            },
          );
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
