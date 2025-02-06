import 'package:frontend/accessability/data/data_provider/auth_data_provider.dart';
import 'package:frontend/accessability/data/model/login_model.dart';
import 'package:frontend/accessability/data/model/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepository {
  SharedPreferences? _sharedPrefs;
  final AuthDataProvider dataProvider;
  UserModel? _cachedUser;

  AuthRepository(this.dataProvider) {
    _initSharedPrefs();
  }

  //! Initialize SharedPreferences
  Future<void> _initSharedPrefs() async {
    _sharedPrefs = await SharedPreferences.getInstance();
  }

  //! Login
  Future<LoginModel> login(String email, String password) async {
    try {
      final data = await dataProvider.login(email, password);

      if (data['token'] == null ||
          data['data'] == null ||
          data['data']['user'] == null) {
        throw Exception('Login failed: Missing token or user data');
      }

      final userModel = UserModel.fromJson(
          data['data']['user']); // Adjusted to fetch 'user' properly
      _cacheUser(userModel); // Cache user data
      return LoginModel.fromJson(data);
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  //! Check Onboarding Status
  Future<bool> checkOnboardingStatus() async {
    try {
      final user = await getCachedUser();
      return user?.hasCompletedOnboarding ?? false; // Access directly
    } catch (e) {
      return false; // Default to false on error
    }
  }

  //! Complete Onboarding
  Future<void> completeOnboarding() async {
    try {
      await dataProvider.completeOnboarding();
      // Update cached user onboarding status using copyWith
      if (_cachedUser != null) {
        _cachedUser = _cachedUser!.copyWith(hasCompletedOnboarding: true);
      }
      // Optionally, update shared preferences here if necessary
      _sharedPrefs?.setBool('hasCompletedOnboarding', true);
    } catch (e) {
      throw Exception('Failed to complete onboarding: ${e.toString()}');
    }
  }

  //! Caching User Data
  void _cacheUser(UserModel user) {
    _cachedUser = user;
    _sharedPrefs?.setString('userId', user.id);
    _sharedPrefs?.setString('userName', user.name);
    _sharedPrefs?.setString('userEmail', user.email);
    _sharedPrefs?.setString(
        'jwtToken', user.token ?? ''); // Save token for later use
    // Store the hasCompletedOnboarding flag in shared preferences
    _sharedPrefs?.setBool(
        'hasCompletedOnboarding', user.hasCompletedOnboarding ?? false);
  }

  //! Get Cached User Data
  Future<UserModel?> getCachedUser() async {
    if (_cachedUser != null) {
      return _cachedUser;
    }

    final userId = _sharedPrefs?.getString('userId');
    final userName = _sharedPrefs?.getString('userName');
    final userEmail = _sharedPrefs?.getString('userEmail');
    final hasCompletedOnboarding =
        _sharedPrefs?.getBool('hasCompletedOnboarding');
    final token = _sharedPrefs?.getString('jwtToken');

    if (userId != null && userName != null && userEmail != null) {
      return UserModel(
        id: userId,
        name: userName,
        email: userEmail,
        token: token ?? '', // Use fallback value if token is null
        password: '', // Or default value
        details: UserDetails(
            address: '', // Default empty string if null
            phoneNumber: _sharedPrefs?.getString('phoneNumber') ??
                '', // Default empty string if null
            profilePicture: ''), // Default empty string if null
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
        hasCompletedOnboarding:
            hasCompletedOnboarding ?? false, // Fetch from prefs
      );
    }
    return null;
  }

  //! Clear Cache
  void clearUserCache() {
    _cachedUser = null;
    _sharedPrefs?.remove('userId');
    _sharedPrefs?.remove('userName');
    _sharedPrefs?.remove('userEmail');
    _sharedPrefs?.remove('jwtToken'); // Remove token as well
    _sharedPrefs?.remove('hasCompletedOnboarding');
  }
}
