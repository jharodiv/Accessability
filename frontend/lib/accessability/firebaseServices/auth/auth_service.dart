import 'package:accessability/accessability/backgroundServices/place_notification_service.dart';
import 'package:accessability/accessability/firebaseServices/chat/fcm_service.dart';
import 'package:accessability/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Register with profile picture
  Future<UserCredential> signUpWithEmailAndPassword(
    String email,
    String password,
    String username,
    String firstName,
    String lastName,
    String contactNumber,
    XFile? profilePicture,
  ) async {
    try {
      // Step 1: Create the user
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception("User creation failed");
      }

      // Step 2: Send email verification
      await user.sendEmailVerification();

      // Step 3: Upload the profile picture (if provided)
      String? profilePictureUrl;
      if (profilePicture != null) {
        profilePictureUrl =
            await uploadProfilePicture(user.uid, profilePicture);
      }

      // Step 4: Save user data in Firestore
      await _firestore.collection('Users').doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'username': username,
        'firstName': firstName,
        'lastName': lastName,
        'contactNumber': contactNumber,
        'profilePicture': profilePictureUrl ??
            'https://firebasestorage.googleapis.com/v0/b/accessability-71ef7.firebasestorage.app/o/profile_pictures%2Fdefault_profile.png?alt=media&token=bc7a75a7-a78e-4460-b816-026a8fc341ba',
        'hasCompletedOnboarding': false,
        'emailVerified': false, // Track email verification status
      });

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  // Upload profile picture to Firebase Storage
  Future<String?> uploadProfilePicture(String uid, XFile imageFile) async {
    try {
      Reference storageReference =
          _firebaseStorage.ref().child('profile_pictures/$uid.jpg');
      await storageReference.putFile(File(imageFile.path));
      String downloadURL = await storageReference.getDownloadURL();
      return downloadURL;
    } catch (e) {
      print('Error uploading profile picture: $e');
      return null;
    }
  }

  // Login
  // Login with enhanced error handling
  Future<UserCredential> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      // Validate email format
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        throw FirebaseAuthException(
          code: 'invalid-email',
          message: 'Please enter a valid email address',
        );
      }

      // Attempt Firebase login
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Authentication failed - no user returned',
        );
      }

      // Check email verification
      if (!user.emailVerified) {
        await _auth.signOut(); // Prevent access until verified
        throw FirebaseAuthException(
          code: 'email-not-verified',
          message: 'Please verify your email before logging in',
        );
      }

      // Update FCM token if available
      final fcmToken =
          await FCMService(navigatorKey: navigatorKey).getFCMToken();
      if (fcmToken != null) {
        await _firestore.collection('Users').doc(user.uid).update({
          'fcmToken': fcmToken,
        });
      }

      final placeService = PlaceNotificationService();
      placeService.updateUserId(user.uid);

      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        // Custom message for non-existent account
        throw FirebaseAuthException(
          code: e.code,
          message:
              'No account found with this email. Would you like to register?',
        );
      }
      // Re-throw with improved messages
      throw FirebaseAuthException(
        code: e.code,
        message: _getUserFriendlyError(e.code),
      );
    } catch (e) {
      // Handle non-Firebase exceptions
      if (e.toString().contains('network')) {
        throw FirebaseAuthException(
          code: 'network-error',
          message: 'No internet connection. Please check your network.',
        );
      }
      throw FirebaseAuthException(
        code: 'login-failed',
        message: 'Login failed. Please try again.',
      );
    }
  }

  String _getUserFriendlyError(String code) {
    switch (code) {
      // Firebase Auth Errors
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'invalid-credential':
      case 'wrong-password':
        return 'The email or password is incorrect.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'No internet connection. Check your network.';
      case 'email-not-verified':
        return 'Please verify your email first. Check your inbox.';

      // Custom Errors
      case 'network-error':
        return 'Network error. Please check your connection.';

      // Default
      default:
        return 'Login failed. Please try again.';
    }
  }

  //Logout and clear fcm token + stop background service
  Future<void> signOut() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Clear the FCM token from Firestore
        await _firestore.collection('Users').doc(user.uid).update({
          'fcmToken': FieldValue.delete(), // Remove the FCM token
        });
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_active_space_id');

      final placeService = PlaceNotificationService();
      placeService.updateUserId(null);

      // Stop the background service if it is running
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      if (isRunning) {
        try {
          service.invoke('stopService'); // Remove the `await` keyword
        } catch (e) {
          print('Error stopping background service: $e');
        }
      }

      // Sign out the user
      await _auth.signOut();
    } catch (e) {
      print('Error during logout: $e');
      throw Exception('Failed to logout: $e');
    }
  }

  // Complete Onboarding
  Future<void> completeOnboarding(String uid) async {
    try {
      // Update Firestore
      await _firestore.collection('Users').doc(uid).update({
        'hasCompletedOnboarding': true,
      });
      print('AuthService: Onboarding status updated for user $uid');

      // Cache the updated status in SharedPreferences
      final sharedPrefs = await SharedPreferences.getInstance();
      await sharedPrefs.setBool('user_hasCompletedOnboarding', true);
      print('Cached updated onboarding status for user $uid');
    } catch (e) {
      print('AuthService: Error updating onboarding status - ${e.toString()}');
      throw Exception('Failed to update onboarding status: ${e.toString()}');
    }
  }

  Future<String?> updateProfilePicture(String uid, XFile imageFile) async {
    try {
      // Upload the new profile picture to Firebase Storage
      Reference storageReference =
          _firebaseStorage.ref().child('profile_pictures/$uid.jpg');
      await storageReference.putFile(File(imageFile.path));
      String downloadURL = await storageReference.getDownloadURL();

      // Update the user's profile picture URL in Firestore
      await _firestore.collection('Users').doc(uid).update({
        'profilePicture': downloadURL,
      });

      return downloadURL;
    } catch (e) {
      print('Error updating profile picture: $e');
      return null;
    }
  }

  Future<void> saveFCMToken(String uid) async {
    String? fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      await _firestore.collection('Users').doc(uid).update({
        'fcmToken': fcmToken,
      });
    }
  }

  Future<void> updateEmailVerificationStatus(String uid) async {
    final user = _auth.currentUser;
    if (user != null && user.emailVerified) {
      await _firestore.collection('Users').doc(uid).update({
        'emailVerified': true,
      });
    }
  }

  // Forgot Password
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No user is currently signed in.',
      );
    }

    // 1) Reauthenticate with the current password.
    //    If it fails, this call throws FirebaseAuthException(code: 'wrong-password').
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);

    // 2) Now update to the new password.
    //    If it’s too weak or requires a recent login, this call
    //    throws the appropriate FirebaseAuthException (e.g. 'weak-password').
    await user.updatePassword(newPassword);
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("No user is currently logged in.");
    }

    // Remove the FCM token from Firestore.
    await _firestore.collection('Users').doc(user.uid).update({
      'fcmToken': FieldValue.delete(),
    });

    // Stop the background service if it is running.
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (isRunning) {
      try {
        service.invoke('stopService');
      } catch (e) {
        print('Error stopping background service: $e');
      }
    }

    // Delete the user's Firestore document.
    await _firestore.collection('Users').doc(user.uid).delete();

    // Delete the FirebaseAuth user.
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      // Firebase may require reauthentication before deletion.
      throw Exception("Account deletion failed: ${e.message}");
    }
  }
}
