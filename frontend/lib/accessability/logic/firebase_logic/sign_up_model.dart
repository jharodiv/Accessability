class SignUpModel {
  final String username;
  final String firstName;
  final String lastName;
  final String email;
  final String password;
  final String contactNumber;
  final String address; // NEW
  final double latitude; // NEW
  final double longitude; // NEW

  SignUpModel({
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
    required this.contactNumber,
    required this.address,
    required this.latitude,
    required this.longitude,
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
        'address': address,
      },
    };
  }
}
