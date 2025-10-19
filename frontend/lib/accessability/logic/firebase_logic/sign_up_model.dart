class SignUpModel {
  final String username;
  final String firstName;
  final String lastName;
  final String email;
  final String password;
  final String contactNumber;
  final String address;
  final double latitude;
  final double longitude;
  final String pwdType;

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
    required this.pwdType,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': username,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'password': password,
      'pwdType': pwdType,
      'details': {
        'contactNumber': contactNumber,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
      },
    };
  }
}
