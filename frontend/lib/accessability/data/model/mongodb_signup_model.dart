class MongodbSignupModel {
  final String username;
  final String email;
  final String contactNumber;
  final String password;

  // Constructor to initialize the MongodbSignupModel
  MongodbSignupModel({
    required this.username,
    required this.email,
    required this.contactNumber,
    required this.password,
  });

  // Convert the MongodbSignupModel to JSON format
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'contactNumber': contactNumber,
      'password': password,
    };
  }

  // Create a MongodbSignupModel from JSON format
  factory MongodbSignupModel.fromJson(Map<String, dynamic> json) {
    return MongodbSignupModel(
      username: json['username'],
      email: json['email'],
      contactNumber: json['contactNumber'],
      password: json['password'],
    );
  }
}
