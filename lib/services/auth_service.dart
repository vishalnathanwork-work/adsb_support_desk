import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/user_model.dart';
import 'notification_listener.dart';

class AuthResult {
  final bool success;
  final UserModel? user;
  final String? message;

  AuthResult({
    required this.success,
    this.user,
    this.message,
  });
}

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  static const String _internalDomain = 'adsb.local';

  static String _usernameToEmail(String username) {
    return '${username.trim().toLowerCase()}@$_internalDomain';
  }

  static String emailToUsername(String email) {
    final atIndex = email.indexOf('@');
    if (atIndex <= 0) return email;
    return email.substring(0, atIndex);
  }

  String? get currentUserEmail => _auth.currentUser?.email;
  String? get currentUserId => _auth.currentUser?.uid;

  // ═══════════════════════════════════════════════
  // USERNAME AVAILABILITY
  // ═══════════════════════════════════════════════

  Future<bool> isUsernameAvailable(String username) async {
    try {
      final clean = username.trim().toLowerCase();
      if (clean.isEmpty || clean.length < 3) return false;

      // Format check
      if (!RegExp(r'^[a-z0-9_.]+$').hasMatch(clean)) return false;

      final callable = FirebaseFunctions.instance
          .httpsCallable('checkUsernameAvailable');
      final result = await callable.call({'username': clean});

      return result.data['available'] == true;
    } catch (e) {
      debugPrint('isUsernameAvailable error: $e');
      // On error, return TRUE so the user isn't wrongly blocked
      // The backend reauthenticate will fail at createUserWithEmailAndPassword
      // with a clear error message if the username truly is taken.
      return true;
    }
  }

  // ═══════════════════════════════════════════════
  // CURRENT USER
  // ═══════════════════════════════════════════════

  Future<UserModel?> getCurrentUserProfile() async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) return null;

      final doc =
      await _firestore.collection('users').doc(firebaseUser.uid).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      return UserModel.fromJson({
        ...data,
        'email': data['email'] ?? firebaseUser.email ?? '',
      });
    } catch (e) {
      print('getCurrentUserProfile error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════
  // LOGIN
  // ═══════════════════════════════════════════════

  Future<AuthResult> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    try {
      final input = usernameOrEmail.trim().toLowerCase();
      final email =
      input.contains('@') ? input : '${input}@$_internalDomain';

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = credential.user!;
      final uid = firebaseUser.uid;

      final doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists) {
        await _auth.signOut();
        return AuthResult(
          success: false,
          message: 'User profile not found. Contact admin.',
        );
      }

      final data = doc.data()!;
      final user = UserModel.fromJson({
        ...data,
        'email': data['email'] ?? firebaseUser.email ?? '',
      });

      final approvalStatus =
      (data['approval_status'] ?? '').toString().toLowerCase();
      final isActive = data['is_active'] == true;

      print('=== LOGIN DEBUG ===');
      print('uid: $uid');
      print('username: ${data['username']}');
      print('role: ${data['role']}');
      print('approval_status: $approvalStatus');
      print('is_active: $isActive');
      print('=== END ===');

      if (approvalStatus == 'rejected') {
        await _auth.signOut();
        return AuthResult(
          success: false,
          message: 'Your registration was rejected. '
              'Please contact ADSB support for more information.',
        );
      }

      if (!isActive) {
        return AuthResult(success: true, user: user);
      }

      return AuthResult(success: true, user: user);
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this username.';
          break;
        case 'wrong-password':
          message = 'Incorrect password.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Try again later.';
          break;
        case 'invalid-credential':
          message = 'Invalid username or password.';
          break;
        case 'invalid-email':
          message = 'Invalid username. Use letters and numbers only.';
          break;
      }
      return AuthResult(success: false, message: message);
    } catch (e) {
      return AuthResult(success: false, message: 'Error: $e');
    }
  }

  // ═══════════════════════════════════════════════
  // REGISTER
  // ═══════════════════════════════════════════════

  Future<AuthResult> register({
    required String username,
    required String name,
    required String password,
    required String phone,
    required String remark,
  }) async {
    UserCredential? credential;

    try {
      final cleanUsername = username.trim().toLowerCase();
      final internalEmail = _usernameToEmail(cleanUsername);

      final available = await isUsernameAvailable(cleanUsername);
      if (!available) {
        return AuthResult(
          success: false,
          message: 'This username is already taken. Please choose another.',
        );
      }

      credential = await _auth.createUserWithEmailAndPassword(
        email: internalEmail,
        password: password,
      );

      final firebaseUser = credential.user!;
      final uid = firebaseUser.uid;

      await firebaseUser.getIdToken(true);

      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'username': cleanUsername,
        'email': internalEmail,
        'name': name.trim(),
        'phone': phone.trim(),
        'remark': remark.trim(),
        'role': 'owner',
        'company': null,
        'client_id': null,
        'client_name': null,
        'site_ids': <String>[],
        'is_active': false,
        'approval_status': 'pending',
        'registered_at': FieldValue.serverTimestamp(),
        'approved_at': null,
        'approved_by': null,
        'updated_at': FieldValue.serverTimestamp(),
      });

      final user = UserModel(
        email: internalEmail,
        username: cleanUsername,
        name: name.trim(),
        role: 'owner',
        phone: phone.trim(),
        remark: remark.trim(),
        isActive: false,
        approvalStatus: 'pending',
        registeredAt: DateTime.now(),
      );

      print('✅ User created: $cleanUsername ($uid)');
      return AuthResult(success: true, user: user);
    } on FirebaseAuthException catch (e) {
      String message = 'Registration failed';
      switch (e.code) {
        case 'email-already-in-use':
          message = 'This username is already taken. Please choose another.';
          break;
        case 'weak-password':
          message = 'Password is too weak. Minimum 6 characters.';
          break;
      }
      return AuthResult(success: false, message: message);
    } on FirebaseException catch (e) {
      print('❌ Firestore error: ${e.code} ${e.message}');
      if (credential != null && credential.user != null) {
        try {
          await credential.user!.delete();
        } catch (_) {}
      }
      String message;
      switch (e.code) {
        case 'permission-denied':
          message = 'Database permission denied. Please contact support.';
          break;
        case 'unavailable':
          message = 'Network error. Please check your connection.';
          break;
        default:
          message = 'Could not save your profile. Please try again.';
      }
      return AuthResult(success: false, message: message);
    } catch (e) {
      print('❌ Unknown error: $e');
      if (credential != null && credential.user != null) {
        try {
          await credential.user!.delete();
        } catch (_) {}
      }
      return AuthResult(
        success: false,
        message: 'Could not save your profile. Please try again.',
      );
    }
  }

  // ═══════════════════════════════════════════════
  // ADMIN RESET PASSWORD
  // ═══════════════════════════════════════════════

  Future<AuthResult> adminResetPassword({
    required String targetUid,
    required String newPassword,
  }) async {
    try {
      final uid = targetUid.trim();

      if (uid.isEmpty) {
        return AuthResult(
          success: false,
          message: 'User UID is missing.',
        );
      }

      if (newPassword.length < 6) {
        return AuthResult(
          success: false,
          message: 'Password must be at least 6 characters.',
        );
      }

      // Must match the Cloud Function deployment region.
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('adminResetPassword');

      debugPrint('Reset password target UID: $uid');

      await callable.call({
        'targetUid': uid,
        'newPassword': newPassword,
      });

      return AuthResult(
        success: true,
        message: 'Password reset successfully.',
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        'Password reset error: code=${e.code}, message=${e.message}',
      );

      String message;

      switch (e.code) {
        case 'permission-denied':
          message = 'Only admins can reset passwords.';
          break;
        case 'invalid-argument':
          message = e.message ?? 'Invalid password.';
          break;
        case 'not-found':
          message =
          'User not found, or the function endpoint was not found. Check the UID and region.';
          break;
        default:
          message = e.message ?? 'Failed to reset password.';
      }

      return AuthResult(success: false, message: message);
    } catch (e) {
      debugPrint('Unexpected password reset error: $e');

      return AuthResult(
        success: false,
        message: 'Error resetting password. Please try again.',
      );
    }
  }

  // ═══════════════════════════════════════════════
  // CHANGE PASSWORD (self-service)
  // ═══════════════════════════════════════════════

  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult(
          success: false,
          message: 'You must be logged in to change your password.',
        );
      }
      if (user.email == null) {
        return AuthResult(
          success: false,
          message: 'Current account has no login identifier.',
        );
      }
      if (newPassword.length < 6) {
        return AuthResult(
          success: false,
          message: 'New password must be at least 6 characters.',
        );
      }
      if (currentPassword == newPassword) {
        return AuthResult(
          success: false,
          message: 'New password must be different from current password.',
        );
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      try {
        await user.reauthenticateWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          return AuthResult(
            success: false,
            message: 'Current password is incorrect.',
          );
        }
        if (e.code == 'too-many-requests') {
          return AuthResult(
            success: false,
            message: 'Too many attempts. Please wait a few minutes.',
          );
        }
        return AuthResult(
          success: false,
          message: 'Could not verify current password.',
        );
      }

      try {
        await user.updatePassword(newPassword);
        return AuthResult(
          success: true,
          message: 'Password updated successfully.',
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'weak-password') {
          return AuthResult(
            success: false,
            message: 'New password is too weak.',
          );
        }
        if (e.code == 'requires-recent-login') {
          return AuthResult(
            success: false,
            message: 'Please log out and log in again, then retry.',
          );
        }
        return AuthResult(
          success: false,
          message: 'Could not update password.',
        );
      }
    } catch (e) {
      return AuthResult(success: false, message: 'Error: $e');
    }
  }

  // ═══════════════════════════════════════════════
  // LOGOUT
  // ═══════════════════════════════════════════════

  Future<void> logout() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.email != null) {
        final safeKey = currentUser.email!.replaceAll('.', '_');
        await _firestore.collection('fcm_tokens').doc(safeKey).delete();
      }
    } catch (e) {
      print('Failed to delete FCM token: $e');
    }

    await AppNotificationListener().stop();
    await _auth.signOut();
  }
}