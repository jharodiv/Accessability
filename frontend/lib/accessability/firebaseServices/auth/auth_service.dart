import 'package:AccessAbility/accessability/firebaseServices/chat/fcm_service.dart';
import 'package:AccessAbility/main.dart';
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
  late FCMService _fcmService;
  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Register with profile picture
  Future<UserCredential> signUpWithEmailAndPassword(
    String email,
    String password,
    String username,
    String contactNumber,
    XFile? profilePicture, // Pass the profile picture file
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

      // Step 2: Upload the profile picture (if provided)
      String? profilePictureUrl;
      if (profilePicture != null) {
        profilePictureUrl =
            await uploadProfilePicture(user.uid, profilePicture);
      }

      // Step 3: Save user data in Firestore
      await _firestore.collection('Users').doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'username': username,
        'contactNumber': contactNumber,
        'profilePicture': profilePictureUrl ??
            'https://firebasestorage.googleapis.com/v0/b/accessability-71ef7.firebasestorage.app/o/profile_pictures%2Fdefault_profile.png?alt=media&token=bc7a75a7-a78e-4460-b816-026a8fc341ba', // Save profile picture URL
        'hasCompletedOnboarding': false,
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
  Future<UserCredential> signInWithEmailPassword(
      String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);

      if (userCredential.user == null) {
        throw Exception("Login failed");
      }

      // Save FCM token after login
      String? fcmToken =
          await FCMService(navigatorKey: navigatorKey).getFCMToken();
      if (fcmToken != null) {
        await _firestore
            .collection('Users')
            .doc(userCredential.user!.uid)
            .update({
          'fcmToken': fcmToken,
        });
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
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
}
