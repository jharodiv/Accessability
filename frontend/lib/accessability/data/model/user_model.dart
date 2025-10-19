class UserModel {
  final String uid;
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
  final bool biometricEnabled;
  final String? deviceId;
  final String? pwdType; // ✅ Outside of details now

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
    this.hasCompletedOnboarding = false,
    this.biometricEnabled = false,
    this.deviceId,
    this.pwdType,
  });

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
    String? pwdType,
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
      pwdType: pwdType ?? this.pwdType,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      username: json['username'] ?? 'Unknown',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      email: json['email'] ?? '',
      contactNumber: json['contactNumber'] ?? '',
      profilePicture: json['profilePicture'] ?? '',
      details: UserDetails.fromJson(json['details'] ?? {}),
      settings: UserSettings.fromJson(json['settings'] ?? {}),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ??
          DateTime.now(), // safer parsing
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      hasCompletedOnboarding: json['hasCompletedOnboarding'] ?? false,
      biometricEnabled: json['biometricEnabled'] ?? false,
      deviceId: json['deviceId'],
      pwdType: json['pwdType']?.toString(), // ✅ Now only reads top-level field
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
      'profilePicture': profilePicture,
      'details': details.toJson(),
      'settings': settings.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'biometricEnabled': biometricEnabled,
      'deviceId': deviceId,
      'pwdType': pwdType, // ✅ outside details
    };
  }
}

class UserDetails {
  final String address;
  final String phoneNumber;
  final String profilePicture;

  UserDetails({
    this.address = '',
    this.phoneNumber = '',
    this.profilePicture = '',
  });

  factory UserDetails.fromJson(Map<String, dynamic> json) {
    return UserDetails(
      address: json['address'] ?? '',
      phoneNumber: json['phoneNumber'] ?? json['contactNumber'] ?? '',
      profilePicture: json['profilePicture'] ?? '',
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
    this.verificationCode = '',
    this.codeExpiresAt = '',
    this.verified = false,
    this.passwordChangedAt = '',
    this.passwordResetToken = '',
    this.passwordResetExpiresAt = '',
    this.active = true,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      verificationCode: json['verificationCode'] ?? '',
      codeExpiresAt: json['codeExpiresAt'] ?? '',
      verified: json['verified'] ?? false,
      passwordChangedAt: json['passwordChangedAt'] ?? '',
      passwordResetToken: json['passwordResetToken'] ?? '',
      passwordResetExpiresAt: json['passwordResetExpiresAt'] ?? '',
      active: json['active'] ?? true,
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
