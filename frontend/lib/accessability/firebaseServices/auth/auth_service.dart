import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:frontend/accessability/firebaseServices/chat/fcm_service.dart';
import 'package:frontend/main.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late FCMService _fcmService;

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Register
  Future<UserCredential> signUpWithEmailAndPassword(
      String email, String password, String username, String contactNumber) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      if (userCredential.user == null) {
        throw Exception("User creation failed");
      }

      String uid = userCredential.user!.uid;
      String? fcmToken = await _fcmService.getFCMToken();

      await _firestore.collection('Users').doc(uid).set({
        'uid': uid,
        'email': email,
        'username': username,
        'contactNumber': contactNumber,
        'hasCompletedOnboarding': false,
      });

      if (fcmToken != null) {
        await _firestore.collection('Users').doc(uid).update({
          'fcmToken': fcmToken,
        });
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  // Login
  Future<UserCredential> signInWithEmailPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);

      if (userCredential.user == null) {
        throw Exception("Login failed");
      }

     // Save FCM token after login
    String? fcmToken = await FCMService(navigatorKey: navigatorKey).getFCMToken();
    if (fcmToken != null) {
      await _firestore.collection('Users').doc(userCredential.user!.uid).update({
        'fcmToken': fcmToken,
      });
    }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  // Logout
  Future<void> signOut() async {
    return await _auth.signOut();
  }

  // Complete Onboarding
  Future<void> completeOnboarding(String uid) async {
    try {
      await _firestore.collection('Users').doc(uid).update({
        'hasCompletedOnboarding': true,
      });
      print('AuthService: Onboarding status updated for user $uid');
    } catch (e) {
      print('AuthService: Error updating onboarding status - ${e.toString()}');
      throw Exception('Failed to update onboarding status: ${e.toString()}');
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