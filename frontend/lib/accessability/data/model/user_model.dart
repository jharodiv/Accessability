class User {
  final String id;
  final String name;
  final String email;
  final String password;
  final UserDetails details;
  final UserSettings settings;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.details,
    required this.settings,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'],
      name: json['name'],
      email: json['email'],
      password: json['password'],
      details: UserDetails.fromJson(json['details']),
      settings: UserSettings.fromJson(json['settings']),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'email': email,
      'password': password,
      'details': details.toJson(),
      'settings': settings.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class UserDetails {
  final String? address;
  final String phoneNumber;
  final String profilePicture;

  UserDetails({
    required this.address,
    required this.phoneNumber,
    required this.profilePicture,
  });

  factory UserDetails.fromJson(Map<String, dynamic> json) {
    return UserDetails(
      address: json['address'],
      phoneNumber: json['phoneNumber'],
      profilePicture: json['profilePicture'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'phoneNumber': phoneNumber,
      'profilePicture': profilePicture,
    };
  }
}

class UserSettings {
  final String? verificationCode;
  final String? codeExpiresAt;
  final bool verified;
  final String? passwordChangedAt;
  final String? passwordResetToken;
  final String? passwordResetExpiresAt;
  final bool active;

  UserSettings({
    required this.verificationCode,
    required this.codeExpiresAt,
    required this.verified,
    required this.passwordChangedAt,
    required this.passwordResetToken,
    required this.passwordResetExpiresAt,
    required this.active,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      verificationCode: json['verificationCode'],
      codeExpiresAt: json['codeExpiresAt'],
      verified: json['verified'],
      passwordChangedAt: json['passwordChangedAt'],
      passwordResetToken: json['passwordResetToken'],
      passwordResetExpiresAt: json['passwordResetExpiresAt'],
      active: json['active'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'verificationCode': verificationCode,
      'codeExpiresAt': codeExpiresAt,
      'verified': verified,
      'passwordChangedAt': passwordChangedAt,
      'passwordResetToken': passwordResetToken,
      'passwordResetExpiresAt': passwordResetExpiresAt,
      'active': active,
    };
  }
}
