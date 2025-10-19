import 'package:accessability/accessability/data/model/login_model.dart';
import 'package:accessability/accessability/data/model/user_model.dart';
import 'package:accessability/accessability/data/repositories/user_repository.dart';
import 'package:accessability/accessability/firebaseServices/auth/auth_service.dart';
import 'package:accessability/accessability/logic/firebase_logic/sign_up_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
        signUpModel.firstName,
        signUpModel.lastName,
        signUpModel.contactNumber,
        profilePicture,
        signUpModel.pwdType, // NEW
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Registration failed: User is null');
      }

      // NEW: Create home place after successful registration
      try {
        await authService.createHomePlace(
          user.uid,
          signUpModel.address,
          signUpModel.latitude,
          signUpModel.longitude,
        );
        print('✅ Home place created successfully for new user');
      } catch (e) {
        print('⚠️ Could not create home place, but registration succeeded: $e');
        // Don't throw here - registration succeeded even if home place creation failed
      }

      await Future.delayed(const Duration(seconds: 1));

      // Fetch user data from Firestore
      final userModel = await userRepository.fetchUserData(user.uid);
      if (userModel == null) {
        throw Exception('Registration failed: User data not found');
      }

      return userModel;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(
        code: 'registration-failed',
        message: e.toString(),
      );
    }
  }

  // Login
  Future<LoginModel> login(String email, String password) async {
    try {
      final userCredential =
          await authService.signInWithEmailPassword(email, password);
      final user = userCredential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No user found for this email',
        );
      }

      final userModel = await userRepository.fetchUserData(user.uid);
      if (userModel == null) {
        throw FirebaseAuthException(
          code: 'user-data-missing',
          message: 'User account exists but data is missing',
        );
      }

      userRepository.cacheUserData(userModel);
      return LoginModel(
        token: user.uid,
        userId: user.uid,
        hasCompletedOnboarding: userModel.hasCompletedOnboarding,
        user: userModel,
      );
    } on FirebaseAuthException {
      // Re-throw Firebase errors directly
      rethrow;
    } catch (e) {
      // Wrap other errors in FirebaseAuthException for consistency
      throw FirebaseAuthException(
        code: 'login-failed',
        message: e.toString(),
      );
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

  Future<void> forgotPassword(String email) async {
    try {
      await authService.sendPasswordResetEmail(email);
    } catch (e) {
      throw Exception('Failed to send password reset email: ${e.toString()}');
    }
  }

  // Change Password
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) {
    // Directly forward to AuthService so all FirebaseAuthExceptions
    // (e.g. wrong-password) propagate to your BLoC
    return authService.changePassword(currentPassword, newPassword);
  }

  Future<void> deleteAccount() async {
    try {
      await authService.deleteAccount();
      userRepository.clearUserCache();
    } catch (e) {
      print('AuthRepository: Failed to delete account - ${e.toString()}');
      throw Exception('Failed to delete account: ${e.toString()}');
    }
  }
}
