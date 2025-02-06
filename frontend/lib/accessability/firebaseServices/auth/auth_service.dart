import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Register
  Future<UserCredential> signUpWithEmailAndPassword(
      String email, String password, String username, String contactNumber) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      String uid = userCredential.user!.uid;

      await _firestore.collection('Users').doc(uid).set({
        'uid': uid,
        'email': email,
        'username': username,
        'contactNumber': contactNumber,
        'hasCompletedOnboarding': false,
      });
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
    await FirebaseFirestore.instance.collection('Users').doc(uid).update({
      'hasCompletedOnboarding': true,
    });
    print('AuthService: Onboarding status updated for user $uid');
  } catch (e) {
    print('AuthService: Error updating onboarding status - ${e.toString()}');
    throw Exception('Failed to update onboarding status: ${e.toString()}');
  }
}
}