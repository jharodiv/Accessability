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
    // Parse the necessary fields from the nested JSON structure
    final user = json['data']['user'];
    final settings = user['settings'];

    return LoginModel(
      token: json['token'], // Extract the token from the top level
      userId: user['id'], // Extract the userId from the user object
      hasCompletedOnboarding: settings['hasCompletedOnboarding'] ??
          false, // Extract or default to false
    );
  }
}
