import 'package:equatable/equatable.dart';
import 'package:frontend/accessability/data/model/login_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthenticatedLogin extends AuthState {
  final LoginModel user;

  const AuthenticatedLogin(this.user);

  bool get hasCompletedOnboarding => user.hasCompletedOnboarding;

  @override
  List<Object> get props => [user];
}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object> get props => [message];
}
