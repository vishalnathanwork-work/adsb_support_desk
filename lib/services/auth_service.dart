import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'notification_listener.dart';

class AuthResult {
  final bool success;
  final UserModel? user;
  final String? message;

  AuthResult({required this.success, this.user, this.message});
}

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final uid = credential.user!.uid;
      final doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists) {
        await _auth.signOut();
        return AuthResult(
          success: false,
          message: 'User profile not found. Contact admin.',
        );
      }

      final data = doc.data()!;

      if (data['is_active'] == false) {
        await _auth.signOut();
        return AuthResult(
          success: false,
          message:
          'Your account has been deactivated. Please contact the administrator.',
        );
      }

      return AuthResult(
        success: true,
        user: UserModel.fromJson({
          ...data,
          'email': data['email'] ?? credential.user!.email ?? '',
        }),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found for this email.';
          break;
        case 'wrong-password':
          message = 'Incorrect password.';
          break;
        case 'invalid-email':
          message = 'Invalid email format.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Try again later.';
          break;
        case 'invalid-credential':
          message = 'Invalid email or password.';
          break;
      }
      return AuthResult(success: false, message: message);
    } catch (e) {
      return AuthResult(success: false, message: 'Error: $e');
    }
  }

  /// Sign out the Firebase Auth user AND stop the notification listener.
  /// Every dashboard's logout should call this.
  Future<void> logout() async {
    // Stop the listener first — cancel subscriptions before signOut
    await AppNotificationListener().stop();

    // Then sign out
    await _auth.signOut();
  }
}