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
  final bool hasCompletedOnboarding;

  const AuthenticatedLogin(this.user, {required this.hasCompletedOnboarding});

  @override
  List<Object> get props => [user, hasCompletedOnboarding];
}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object> get props => [message];
}

class AuthSuccess extends AuthState {
  final String message;

  const AuthSuccess(this.message);

  @override
  List<Object> get props => [message];
}

class RegistrationSuccess extends AuthState {}
