import 'package:accessability/accessability/data/model/user_model.dart';

class LoginModel {
  final String token;
  final String userId;
  final bool hasCompletedOnboarding;
  final UserModel user; // Add this line to include user data

  LoginModel({
    required this.token,
    required this.userId,
    required this.hasCompletedOnboarding,
    required this.user, // Add this line to include user data
  });

  factory LoginModel.fromJson(Map<String, dynamic> json) {
    return LoginModel(
      token: json['uid'], // Use Firebase UID as the token
      userId: json['uid'], // Use Firebase UID as the userId
      hasCompletedOnboarding: json['hasCompletedOnboarding'] ?? false,
      user: UserModel.fromJson(
          json['user']), // Assuming you have a UserModel.fromJson method
    );
  }
}
