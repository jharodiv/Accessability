import 'package:AccessAbility/accessability/logic/firebase_logic/SignupModel.dart';
import 'package:image_picker/image_picker.dart';

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
  final SignUpModel signUpModel;
  final XFile? profilePicture;

  RegisterEvent({required this.signUpModel, this.profilePicture});
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

class CheckEmailVerification extends AuthEvent {}

class ForgotPasswordEvent extends AuthEvent {
  final String email;

  ForgotPasswordEvent(this.email);

  @override
  List<Object?> get props => [email];
}

class ChangePasswordEvent extends AuthEvent {
  final String currentPassword;
  final String newPassword;

  ChangePasswordEvent({
    required this.currentPassword,
    required this.newPassword,
  });
}
