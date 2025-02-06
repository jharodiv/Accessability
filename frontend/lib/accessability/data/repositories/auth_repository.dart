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

    return LoginModel(
      token: user.uid, // Use Firebase UID as the token
      userId: user.uid, // Use Firebase UID as the userId
      hasCompletedOnboarding: userData['hasCompletedOnboarding'] ?? false,
    );
  } catch (e) {
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
    print('AuthService: Onboarding status updated for user $uid');
  } catch (e) {
    print('AuthService: Error updating onboarding status - ${e.toString()}');
    throw Exception('Failed to update onboarding status: ${e.toString()}');
  }
}

  // Cache User Data
  void _cacheUser(UserModel user) {
  _cachedUser = user;
  _sharedPrefs?.setString('userId', user.id);
  _sharedPrefs?.setString('userName', user.name);
  _sharedPrefs?.setString('userEmail', user.email);
  _sharedPrefs?.setBool('hasCompletedOnboarding', user.hasCompletedOnboarding);
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
    return UserModel(
      id: userId,
      name: userName,
      email: userEmail,
      token: userId, // Using UID as token for simplicity
      password: '', // Or default value
      details: UserDetails(
          address: '', // Default empty string if null
          phoneNumber: _sharedPrefs?.getString('phoneNumber') ?? '',
          profilePicture: ''),
      settings: UserSettings(
          verificationCode: '',
          codeExpiresAt: '',
          verified: false,
          passwordChangedAt: '',
          passwordResetToken: '',
          passwordResetExpiresAt: '',
          active: true),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      hasCompletedOnboarding: hasCompletedOnboarding ?? false,
    );
  }
  return null;
}

  // Clear Cache
  void clearUserCache() {
    _cachedUser = null;
    _sharedPrefs?.remove('userId');
    _sharedPrefs?.remove('userName');
    _sharedPrefs?.remove('userEmail');
    _sharedPrefs?.remove('hasCompletedOnboarding');
  }
}