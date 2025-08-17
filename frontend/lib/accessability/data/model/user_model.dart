class UserModel {
  final String uid; // Use `uid` instead of `id` to match Firestore
  final String username;
  final String firstName;
  final String lastName;
  final String email;
  final String contactNumber;
  final String profilePicture;
  final UserDetails details;
  final UserSettings settings;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool hasCompletedOnboarding;
  final bool biometricEnabled; // Add this field
  final String? deviceId; // Add this field

  UserModel({
    required this.uid,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.contactNumber,
    required this.profilePicture,
    required this.details,
    required this.settings,
    required this.createdAt,
    required this.updatedAt,
    this.hasCompletedOnboarding = false, // Default value false
    this.biometricEnabled = false, // Default value false
    this.deviceId, // Default value null
  });

  // Copy constructor to create a new instance with updated properties
  UserModel copyWith({
    String? uid,
    String? username,
    String? firstName,
    String? lastName,
    String? email,
    String? contactNumber,
    String? profilePicture,
    UserDetails? details,
    UserSettings? settings,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? hasCompletedOnboarding,
    bool? biometricEnabled,
    String? deviceId,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      contactNumber: contactNumber ?? this.contactNumber,
      profilePicture: profilePicture ?? this.profilePicture,
      details: details ?? this.details,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '', // Fallback to empty string if null
      username: json['username'] ?? 'Unknown', // Fallback to 'Unknown' if null
      firstName: json['firstName'] ?? '', // Fallback to empty string if null
      lastName: json['lastName'] ?? '', // Fallback to empty string if null
      email: json['email'] ?? '', // Fallback to empty string if null
      contactNumber: json['contactNumber'] ?? '',
      profilePicture: json['profilePicture'] ?? '',
      details: UserDetails.fromJson(
          json['details'] ?? {}), // Fallback to empty map if null
      settings: UserSettings.fromJson(
          json['settings'] ?? {}), // Fallback to empty map if null
      createdAt: DateTime.parse(json['createdAt'] ??
          DateTime.now().toIso8601String()), // Fallback to current time if null
      updatedAt: DateTime.parse(json['updatedAt'] ??
          DateTime.now().toIso8601String()), // Fallback to current time if null
      hasCompletedOnboarding:
          json['hasCompletedOnboarding'] ?? false, // Fallback to false if null
      biometricEnabled: json['biometricEnabled'] ?? false,
      deviceId: json['deviceId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'username': username,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'contactNumber': contactNumber,
      'details': details.toJson(),
      'settings': settings.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'biometricEnabled': biometricEnabled,
      'deviceId': deviceId,
    };
  }
}

class UserDetails {
  final String address;
  final String phoneNumber;
  final String profilePicture;

  UserDetails({
    this.address = '', // Default to empty string if null
    this.phoneNumber = '', // Default to empty string if null
    this.profilePicture = '', // Default to empty string if null
  });

  factory UserDetails.fromJson(Map<String, dynamic> json) {
    return UserDetails(
      address: json['address'] ?? '', // Fallback to empty string if null
      phoneNumber:
          json['phoneNumber'] ?? '', // Fallback to empty string if null
      profilePicture:
          json['profilePicture'] ?? '', // Fallback to empty string if null
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
  final String verificationCode;
  final String codeExpiresAt;
  final bool verified;
  final String passwordChangedAt;
  final String passwordResetToken;
  final String passwordResetExpiresAt;
  final bool active;

  UserSettings({
    this.verificationCode = '', // Default to empty string if null
    this.codeExpiresAt = '', // Default to empty string if null
    this.verified = false, // Default to false if null
    this.passwordChangedAt = '', // Default to empty string if null
    this.passwordResetToken = '', // Default to empty string if null
    this.passwordResetExpiresAt = '', // Default to empty string if null
    this.active = true, // Default to true if null
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      verificationCode:
          json['verificationCode'] ?? '', // Fallback to empty string if null
      codeExpiresAt:
          json['codeExpiresAt'] ?? '', // Fallback to empty string if null
      verified: json['verified'] ?? false, // Fallback to false if null
      passwordChangedAt:
          json['passwordChangedAt'] ?? '', // Fallback to empty string if null
      passwordResetToken:
          json['passwordResetToken'] ?? '', // Fallback to empty string if null
      passwordResetExpiresAt: json['passwordResetExpiresAt'] ??
          '', // Fallback to empty string if null
      active: json['active'] ?? true, // Fallback to true if null
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
