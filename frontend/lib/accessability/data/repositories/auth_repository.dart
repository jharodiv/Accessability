import 'package:AccessAbility/accessability/data/model/login_model.dart';
import 'package:AccessAbility/accessability/data/model/user_model.dart';
import 'package:AccessAbility/accessability/data/repositories/user_repository.dart';
import 'package:AccessAbility/accessability/firebaseServices/auth/auth_service.dart';
import 'package:AccessAbility/accessability/logic/firebase_logic/SignupModel.dart';

import 'package:image_picker/image_picker.dart';

class AuthRepository {
  final AuthService authService;
  final UserRepository userRepository;

  AuthRepository(this.authService, this.userRepository);

  // Register with profile picture
  Future<UserModel> register(
    SignUpModel signUpModel,
    XFile? profilePicture,
  ) async {
    try {
      final userCredential = await authService.signUpWithEmailAndPassword(
        signUpModel.email,
        signUpModel.password,
        signUpModel.username,
        signUpModel.contactNumber,
        profilePicture,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Registration failed: User is null');
      }

      await Future.delayed(const Duration(seconds: 1));

      // Fetch user data from Firestore
      final userModel = await userRepository.fetchUserData(user.uid);
      if (userModel == null) {
        throw Exception('Registration failed: User data not found');
      }

      return userModel;
    } catch (e) {
      print('AuthRepository: Registration failed - ${e.toString()}');
      throw Exception('Registration failed: ${e.toString()}');
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

      // Fetch user data from Firestore
      final userModel = await userRepository.fetchUserData(user.uid);
      if (userModel == null) {
        throw Exception('Login failed: User data not found');
      }

      // Cache the user data
      userRepository.cacheUserData(userModel);

      return LoginModel(
        token: user.uid,
        userId: user.uid,
        hasCompletedOnboarding: userModel.hasCompletedOnboarding,
        user: userModel,
      );
    } catch (e) {
      print('AuthRepository: Login failed - ${e.toString()}');
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  // Complete Onboarding
  Future<void> completeOnboarding(String uid) async {
    try {
      await authService.completeOnboarding(uid);
    } catch (e) {
      print(
          'AuthRepository: Error updating onboarding status - ${e.toString()}');
      throw Exception('Failed to update onboarding status: ${e.toString()}');
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await authService.signOut();
      userRepository.clearUserCache();
    } catch (e) {
      print('AuthRepository: Failed to logout - ${e.toString()}');
      throw Exception('Failed to logout: ${e.toString()}');
    }
  }
}
