import 'dart:io';

import 'package:frontend/accessability/data/data_provider/auth_data_provider.dart';
import 'package:frontend/accessability/data/model/mongodb_signup_model.dart';
import 'package:frontend/accessability/logic/firebase_logic/SignupModel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/accessability/firebaseServices/auth/auth_service.dart';
import 'package:frontend/accessability/data/model/login_model.dart';
import 'package:frontend/accessability/data/model/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthRepository {
  SharedPreferences? _sharedPrefs;
  final AuthService authService;
  final AuthDataProvider dataProvider;

  UserModel? _cachedUser;

  AuthRepository(this.authService, this.dataProvider) {
    _initSharedPrefs(); // Initialize SharedPreferences when the repository is created
  }

  // Initialize SharedPreferences
  Future<void> _initSharedPrefs() async {
    _sharedPrefs = await SharedPreferences.getInstance();
    print('SharedPreferences initialized');
  }

  //! Register
  Future<UserModel> register(
      MongodbSignupModel signUpModel, File? profilePicture) async {
    try {
      final data = await dataProvider.register(signUpModel, profilePicture);
      return UserModel.fromJson(
          data); // Assuming the response contains user data
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  //! Send Verification Code
  Future<void> sendVerificationCode(String email) async {
    try {
      await dataProvider.sendVerificationCode(email);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  //! Verify Code
  Future<void> verifyCode(String email, String verificationCode) async {
    try {
      await dataProvider.verifyCode(email, verificationCode);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // Login
  Future<LoginModel> login(String email, String password) async {
    try {
      final userCredential =
          await authService.signInWithEmailPassword(email, password);
      final user = userCredential.user;
      if (user == null) {
        throw Exception('Login failed: User is null');
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();
      if (!userDoc.exists) {
        throw Exception('Login failed: User data not found');
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final userModel = UserModel.fromJson(userData);
      cacheUser(userModel);

      print('AuthRepository: User logged in with UID ${user.uid}');
      return LoginModel(
          token: user.uid, // Use Firebase UID as the token
          userId: user.uid, // Use Firebase UID as the userId
          hasCompletedOnboarding: userData['hasCompletedOnboarding'] ?? false,
          user: userModel);
    } catch (e) {
      print('AuthRepository: Login failed - ${e.toString()}');
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  // Complete Onboarding
  Future<void> completeOnboarding(String uid) async {
    try {
      if (uid.isEmpty) {
        throw Exception('User ID is empty');
      }
      await FirebaseFirestore.instance.collection('Users').doc(uid).update({
        'hasCompletedOnboarding': true,
      });
      print('AuthRepository: Onboarding status updated for user $uid');
    } catch (e) {
      print(
          'AuthRepository: Error updating onboarding status - ${e.toString()}');
      throw Exception('Failed to update onboarding status: ${e.toString()}');
    }
  }

  // Cache User Data
  void cacheUser(UserModel user) {
    _cachedUser = user;
    _sharedPrefs?.setString('user_userId', user.uid);
    _sharedPrefs?.setString('user_userName', user.username);
    _sharedPrefs?.setString('user_userEmail', user.email);
    _sharedPrefs?.setBool(
        'user_hasCompletedOnboarding', user.hasCompletedOnboarding);
    print('AuthRepository: User cached with UID ${user.uid}');
  }

  // Get Cached User Data
  Future<UserModel?> getCachedUser() async {
    if (_cachedUser != null) {
      return _cachedUser;
    }

    final userId = _sharedPrefs?.getString('user_userId');
    final userName = _sharedPrefs?.getString('user_userName');
    final userEmail = _sharedPrefs?.getString('user_userEmail');
    final hasCompletedOnboarding =
        _sharedPrefs?.getBool('user_hasCompletedOnboarding');

    if (userId != null && userName != null && userEmail != null) {
      print('AuthRepository: Retrieved cached user with UID $userId');
      return UserModel(
        uid: userId,
        username: userName,
        email: userEmail,
        contactNumber:
            _sharedPrefs?.getString('user_contactNumber'), // Optional field
        details: UserDetails(
          address: _sharedPrefs?.getString('user_address') ?? '',
          phoneNumber: _sharedPrefs?.getString('user_phoneNumber') ?? '',
          profilePicture: _sharedPrefs?.getString('user_profilePicture') ?? '',
        ),
        settings: UserSettings(
          verificationCode:
              _sharedPrefs?.getString('user_verificationCode') ?? '',
          codeExpiresAt: _sharedPrefs?.getString('user_codeExpiresAt') ?? '',
          verified: _sharedPrefs?.getBool('user_verified') ?? false,
          passwordChangedAt:
              _sharedPrefs?.getString('user_passwordChangedAt') ?? '',
          passwordResetToken:
              _sharedPrefs?.getString('user_passwordResetToken') ?? '',
          passwordResetExpiresAt:
              _sharedPrefs?.getString('user_passwordResetExpiresAt') ?? '',
          active: _sharedPrefs?.getBool('user_active') ?? true,
        ),
        createdAt: DateTime.parse(_sharedPrefs?.getString('user_createdAt') ??
            DateTime.now().toIso8601String()),
        updatedAt: DateTime.parse(_sharedPrefs?.getString('user_updatedAt') ??
            DateTime.now().toIso8601String()),
        hasCompletedOnboarding: hasCompletedOnboarding ?? false,
      );
    }
    print('AuthRepository: No cached user found');
    return null;
  }

  // Clear Cache
  Future<void> clearUserCache() async {
    _cachedUser = null;
    _sharedPrefs?.remove('user_userId');
    _sharedPrefs?.remove('user_userName');
    _sharedPrefs?.remove('user_userEmail');
    _sharedPrefs?.remove('user_hasCompletedOnboarding');
    print('AuthRepository: User cache cleared');
  }
}
