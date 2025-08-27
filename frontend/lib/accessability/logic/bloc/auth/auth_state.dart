import 'package:accessability/accessability/data/model/login_model.dart';
import 'package:accessability/accessability/data/model/user_model.dart';
import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoadingLogin extends AuthState {}

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

class ProfilePictureUpdated extends AuthState {
  final UserModel user;

  const ProfilePictureUpdated(this.user);
}

class EmailVerified extends AuthState {}

class ForgotPasswordSuccess extends AuthState {
  final String message;

  ForgotPasswordSuccess(this.message);

  @override
  List<Object> get props => [message];
}

class ChangePasswordSuccess extends AuthState {
  final String message;

  const ChangePasswordSuccess(this.message);

  @override
  List<Object> get props => [message];
}

class ForgotPasswordFailure extends AuthState {
  final String errorMessage;
  const ForgotPasswordFailure(this.errorMessage);
}

class AuthShowErrorDialog extends AuthState {
  final String title;
  final String message;

  AuthShowErrorDialog(this.title, this.message);
}
