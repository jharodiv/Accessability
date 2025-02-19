import 'dart:io';

import 'package:frontend/accessability/data/model/mongodb_signup_model.dart';

abstract class AuthEvent {}

class LoginEvent extends AuthEvent {
  final String email;
  final String password;

  LoginEvent({required this.email, required this.password});
}

class LogoutEvent extends AuthEvent {}

class CheckAuthStatus extends AuthEvent {} // Add this event

class CompleteOnboardingEvent extends AuthEvent {}

class RegisterEvent extends AuthEvent {
  final MongodbSignupModel signUpModel;
  final File? profilePicture;

  RegisterEvent(this.signUpModel, this.profilePicture);
}

class SendVerificationCodeEvent extends AuthEvent {
  final String email;

  SendVerificationCodeEvent(this.email);
}

class VerifyCodeEvent extends AuthEvent {
  final String email;
  final String verificationCode;

  VerifyCodeEvent(this.email, this.verificationCode);
}

class LoginWithBiometricEvent extends AuthEvent {}
