import 'package:AccessAbility/accessability/data/model/user_model.dart';
import 'package:AccessAbility/accessability/firebaseServices/auth/auth_service.dart';
import 'package:AccessAbility/accessability/firebaseServices/models/emergency_contact.dart';
import 'package:AccessAbility/accessability/firebaseServices/models/place.dart';
import 'package:AccessAbility/accessability/firebaseServices/place/place_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserRepository {
  final FirebaseFirestore _firestore;
  final SharedPreferences? _sharedPrefs;
  final AuthService authService;
  final PlaceService placeService;

  UserRepository(
      this._firestore, this._sharedPrefs, this.authService, this.placeService);

  // Fetch user data from Firestore
  Future<UserModel?> fetchUserData(String uid) async {
    try {
      final userDoc = await _firestore.collection('Users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        print(userData);
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
    _sharedPrefs?.setString('user_profilePicture', user.profilePicture);
    _sharedPrefs?.setString('user_contactNumber', user.contactNumber);

    _sharedPrefs?.setBool(
        'user_hasCompletedOnboarding', user.hasCompletedOnboarding);
    print('User cached: ${user.uid}, ${user.username}, ${user.email}');
  }

  // Get cached user data
  Future<UserModel?> getCachedUser() async {
    final userId = _sharedPrefs?.getString('user_userId');
    final userName = _sharedPrefs?.getString('user_userName');
    final userEmail = _sharedPrefs?.getString('user_userEmail');
    final profilePicture = _sharedPrefs?.getString('user_profilePicture') ?? '';
    final contactNumber = _sharedPrefs?.getString('user_contactNumber') ?? '';
    final hasCompletedOnboarding =
        _sharedPrefs?.getBool('user_hasCompletedOnboarding') ?? false;

    if (userId != null && userName != null && userEmail != null) {
      return UserModel(
        uid: userId,
        username: userName,
        email: userEmail,
        contactNumber: contactNumber,
        profilePicture: profilePicture,
        hasCompletedOnboarding: hasCompletedOnboarding,
        details: UserDetails(
          address: _sharedPrefs?.getString('user_address') ?? '',
          phoneNumber: _sharedPrefs?.getString('user_phoneNumber') ?? '',
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
      );
    }
    return null;
  }

  // Clear cached user data
  void clearUserCache() {
    _sharedPrefs?.remove('user_userId');
    _sharedPrefs?.remove('user_userName');
    _sharedPrefs?.remove('user_userEmail');
    _sharedPrefs?.remove('user_profilePicture');
    _sharedPrefs?.remove('user_contactNumber');
    _sharedPrefs?.remove('user_hasCompletedOnboarding');
    print('User cache cleared');
  }

  Future<UserModel> updateProfilePicture(String uid, XFile imageFile) async {
    try {
      final profilePictureUrl =
          await authService.updateProfilePicture(uid, imageFile);
      if (profilePictureUrl == null) {
        throw Exception('Failed to upload profile picture');
      }

      // Update profile picture URL in Firestore
      await updateUserData(uid, {'profilePicture': profilePictureUrl});

      // Fetch updated user data
      final userModel = await fetchUserData(uid);
      if (userModel == null) {
        throw Exception('User data not found');
      }

      // Cache the updated user data
      cacheUserData(userModel);

      return userModel;
    } catch (e) {
      print('Failed to update profile picture: $e');
      throw Exception('Failed to update profile picture: ${e.toString()}');
    }
  }
}
