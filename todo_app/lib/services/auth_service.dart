import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // Grab the instance of Firebase Auth
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// SIGN UP USER
  Future<User?> signUpWithEmailPassword(String email, String password) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      // If Firebase rejects the signup (e.g., email already in use, weak password),
      // we throw the error message back to the UI to show the user.
      throw Exception(e.message);
    }
  }

  /// LOG IN USER
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      // Throws errors like "wrong password" or "user not found"
      throw Exception(e.message);
    }
  }

  /// LOG OUT USER
  Future<void> logOut() async {
    await _auth.signOut();
  }
}
