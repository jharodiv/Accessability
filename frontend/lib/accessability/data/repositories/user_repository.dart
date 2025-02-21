import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/accessability/data/model/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SharedPreferences? _sharedPrefs;

  UserRepository(this._sharedPrefs);

  // Fetch user data from Firestore
   Future<UserModel?> fetchUserData(String uid) async {
    try {
      final userDoc = await _firestore.collection('Users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return UserModel.fromJson(userData);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch user data: ${e.toString()}');
    }
  }

  // Update user data in Firestore
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('Users').doc(uid).update(data);
    } catch (e) {
      throw Exception('Failed to update user data: ${e.toString()}');
    }
  }

  // Cache user data locally
   void cacheUserData(UserModel user) {
    _sharedPrefs?.setString('user_userId', user.uid);
    _sharedPrefs?.setString('user_userName', user.username);
    _sharedPrefs?.setString('user_userEmail', user.email);
    _sharedPrefs?.setBool('user_hasCompletedOnboarding', user.hasCompletedOnboarding);
    _sharedPrefs?.setString('user_profilePicture', user.profilePicture);
    print('User cached: ${user.uid}, ${user.username}, ${user.email}');
  }


  // Get cached user data
   Future<UserModel?> getCachedUser() async {
    final userId = _sharedPrefs?.getString('user_userId');
    final userName = _sharedPrefs?.getString('user_userName');
    final userEmail = _sharedPrefs?.getString('user_userEmail');
    final hasCompletedOnboarding = _sharedPrefs?.getBool('user_hasCompletedOnboarding');
    final profilePicture = _sharedPrefs?.getString('user_profilePicture') ?? '';
    if (userId != null && userName != null && userEmail != null) {
      return UserModel(
        uid: userId,
        username: userName,
        email: userEmail,
        profilePicture: profilePicture,
        details: UserDetails(
          address: _sharedPrefs?.getString('user_address') ?? '', 
          phoneNumber: _sharedPrefs?.getString('user_phoneNumber') ?? '',
        ),
        settings: UserSettings(
          verificationCode: _sharedPrefs?.getString('user_verificationCode') ?? '',
          codeExpiresAt: _sharedPrefs?.getString('user_codeExpiresAt') ?? '',
          verified: _sharedPrefs?.getBool('user_verified') ?? false,
          passwordChangedAt: _sharedPrefs?.getString('user_passwordChangedAt') ?? '',
          passwordResetToken: _sharedPrefs?.getString('user_passwordResetToken') ?? '',
          passwordResetExpiresAt: _sharedPrefs?.getString('user_passwordResetExpiresAt') ?? '',
          active: _sharedPrefs?.getBool('user_active') ?? true,
        ),
        createdAt: DateTime.parse(_sharedPrefs?.getString('user_createdAt') ?? DateTime.now().toIso8601String()),
        updatedAt: DateTime.parse(_sharedPrefs?.getString('user_updatedAt') ?? DateTime.now().toIso8601String()),
        hasCompletedOnboarding: hasCompletedOnboarding ?? false,
      );
    }
    return null;
  }
}