class SignUpModel {
  final String username;
  final String firstName;
  final String lastName;
  final String email;
  final String password;
  final String contactNumber;

  SignUpModel({
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
    required this.contactNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': username,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'password': password,
      'details': {
        'contactNumber': contactNumber,
      },
    };
  }
}
