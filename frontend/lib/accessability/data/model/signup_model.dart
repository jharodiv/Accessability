class SignUpModel {
  final String username;
  final String email;
  final String contactNumber;
  final String password;

  // Constructor to initialize the SignUpModel
  SignUpModel({
    required this.username,
    required this.email,
    required this.contactNumber,
    required this.password,
  });

  // Convert the SignUpModel to JSON format
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'contactNumber': contactNumber,
      'password': password,
    };
  }

  // Create a SignUpModel from JSON format
  factory SignUpModel.fromJson(Map<String, dynamic> json) {
    return SignUpModel(
      username: json['username'],
      email: json['email'],
      contactNumber: json['contactNumber'],
      password: json['password'],
    );
  }
}
