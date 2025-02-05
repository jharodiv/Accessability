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
      token: json['token'],
      userId: json['userId'],
      hasCompletedOnboarding: json['hasCompletedOnboarding'] ?? false,
    );
  }
}
