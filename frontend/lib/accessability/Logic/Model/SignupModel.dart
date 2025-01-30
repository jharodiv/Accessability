class SignUpModel {
  final String username;
  final String email;
  final String password;
  final String contactNumber;

  SignUpModel({
    required this.username,
    required this.email,
    required this.password,
    required this.contactNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': username,
      'email': email,
      'password': password,
      'details': {
        'contactNumber': contactNumber,
      },
    };
  }
}
