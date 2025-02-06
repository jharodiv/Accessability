import 'package:frontend/accessability/logic/bloc/auth/bloc/auth_state.dart';

abstract class AuthEvent {}

class LoginEvent extends AuthEvent {
  final String email;
  final String password;

  LoginEvent({required this.email, required this.password});
}

class CompleteOnboardingEvent extends AuthEvent {}

class AuthSuccess extends AuthState {
  final String message;

  const AuthSuccess(this.message);

  @override
  List<Object> get props => [message];
}
