import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/accessability/firebaseServices/auth/auth_service.dart';
import 'package:frontend/accessability/data/model/login_model.dart';
import 'package:frontend/accessability/data/model/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthRepository {
  SharedPreferences? _sharedPrefs;
  final AuthService authService;
  UserModel? _cachedUser;

  AuthRepository(this.authService) {
    _initSharedPrefs(); // Initialize SharedPreferences when the repository is created
  }

  // Initialize SharedPreferences
  Future<void> _initSharedPrefs() async {
    _sharedPrefs = await SharedPreferences.getInstance();
    print('SharedPreferences initialized');
  }

  // Login
  Future<LoginModel> login(String email, String password) async {
    try {
      final userCredential = await authService.signInWithEmailPassword(email, password);
      final user = userCredential.user;
      if (user == null) {
        throw Exception('Login failed: User is null');
      }

      final userDoc = await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();
      if (!userDoc.exists) {
        throw Exception('Login failed: User data not found');
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final userModel = UserModel.fromJson(userData);
      _cacheUser(userModel);

      print('AuthRepository: User logged in with UID ${user.uid}');
      return LoginModel(
        token: user.uid, // Use Firebase UID as the token
        userId: user.uid, // Use Firebase UID as the userId
        hasCompletedOnboarding: userData['hasCompletedOnboarding'] ?? false,
      );
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
      print('AuthRepository: Error updating onboarding status - ${e.toString()}');
      throw Exception('Failed to update onboarding status: ${e.toString()}');
    }
  }

  // Cache User Data
  void _cacheUser(UserModel user) {
    _cachedUser = user;
    _sharedPrefs?.setString('userId', user.uid);
    _sharedPrefs?.setString('userName', user.name);
    _sharedPrefs?.setString('userEmail', user.email);
    _sharedPrefs?.setBool('hasCompletedOnboarding', user.hasCompletedOnboarding);
    print('AuthRepository: User cached with UID ${user.uid}');
  }

  // Get Cached User Data
  Future<UserModel?> getCachedUser() async {
    if (_cachedUser != null) {
      return _cachedUser;
    }

    final userId = _sharedPrefs?.getString('userId');
    final userName = _sharedPrefs?.getString('userName');
    final userEmail = _sharedPrefs?.getString('userEmail');
    final hasCompletedOnboarding = _sharedPrefs?.getBool('hasCompletedOnboarding');

    if (userId != null && userName != null && userEmail != null) {
      print('AuthRepository: Retrieved cached user with UID $userId');
      return UserModel(
        uid: userId,
        name: userName,
        email: userEmail,
        contactNumber: _sharedPrefs?.getString('contactNumber'), // Optional field
        details: UserDetails(
          address: _sharedPrefs?.getString('address') ?? '',
          phoneNumber: _sharedPrefs?.getString('phoneNumber') ?? '',
          profilePicture: _sharedPrefs?.getString('profilePicture') ?? '',
        ),
        settings: UserSettings(
          verificationCode: _sharedPrefs?.getString('verificationCode') ?? '',
          codeExpiresAt: _sharedPrefs?.getString('codeExpiresAt') ?? '',
          verified: _sharedPrefs?.getBool('verified') ?? false,
          passwordChangedAt: _sharedPrefs?.getString('passwordChangedAt') ?? '',
          passwordResetToken: _sharedPrefs?.getString('passwordResetToken') ?? '',
          passwordResetExpiresAt: _sharedPrefs?.getString('passwordResetExpiresAt') ?? '',
          active: _sharedPrefs?.getBool('active') ?? true,
        ),
        createdAt: DateTime.parse(_sharedPrefs?.getString('createdAt') ?? DateTime.now().toIso8601String()),
        updatedAt: DateTime.parse(_sharedPrefs?.getString('updatedAt') ?? DateTime.now().toIso8601String()),
        hasCompletedOnboarding: hasCompletedOnboarding ?? false,
      );
    }
    print('AuthRepository: No cached user found');
    return null;
  }

  // Clear Cache
  void clearUserCache() {
    _cachedUser = null;
    _sharedPrefs?.remove('userId');
    _sharedPrefs?.remove('userName');
    _sharedPrefs?.remove('userEmail');
    _sharedPrefs?.remove('hasCompletedOnboarding');
    print('AuthRepository: User cache cleared');
  }
}