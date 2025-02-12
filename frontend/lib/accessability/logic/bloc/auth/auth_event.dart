abstract class AuthEvent {}

class LoginEvent extends AuthEvent {
  final String email;
  final String password;

  LoginEvent({required this.email, required this.password});
}

class CheckAuthStatus extends AuthEvent {} // Add this event

class CompleteOnboardingEvent extends AuthEvent {}