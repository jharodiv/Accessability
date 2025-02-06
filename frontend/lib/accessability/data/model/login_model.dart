class LoginModel {
  final String token;
  final String userId;
  final bool hasCompletedOnboarding;

  LoginModel({
    required this.token,
    required this.userId,
    required this.hasCompletedOnboarding,
  });

  factory LoginModel.fromJson(Map<String, dynamic> json) {
    return LoginModel(
      token: json['uid'], // Use Firebase UID as the token
      userId: json['uid'], // Use Firebase UID as the userId
      hasCompletedOnboarding: json['hasCompletedOnboarding'] ?? false,
    );
  }
}