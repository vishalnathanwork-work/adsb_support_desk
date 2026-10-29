import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/user_model.dart';
import 'notification_listener.dart';
import 'session_guard_service.dart';

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
  // PASSWORD RESET
  // ═══════════════════════════════════════════════

  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      if (cleanEmail.isEmpty) {
        return AuthResult(
            success: false, message: 'Please enter your email address.');
      }
      if (!cleanEmail.contains('@')) {
        return AuthResult(
            success: false, message: 'Please enter a valid email address.');
      }

      await _auth.sendPasswordResetEmail(email: cleanEmail);
      return AuthResult(
        success: true,
        message: 'Password reset email sent. Check your inbox.',
      );
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email.';
          break;
        case 'invalid-email':
          message = 'The email address is not valid.';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Please try again later.';
          break;
        default:
          message = e.message ?? 'Failed to send reset email.';
      }
      return AuthResult(success: false, message: message);
    } catch (e) {
      return AuthResult(success: false, message: 'Error: $e');
    }
  }

  // ═══════════════════════════════════════════════
  // USERNAME AVAILABILITY
  // ═══════════════════════════════════════════════

  Future<bool> isUsernameAvailable(String username) async {
    try {
      final clean = username.trim().toLowerCase();
      if (clean.isEmpty || clean.length < 3) return false;
      if (!RegExp(r'^[a-z0-9_.]+$').hasMatch(clean)) return false;

      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('checkUsernameAvailable');
      final result = await callable.call({'username': clean});
      return result.data['available'] == true;
    } catch (e) {
      debugPrint('isUsernameAvailable error: $e');
      return true;
    }
  }

  // ═══════════════════════════════════════════════
  // SYNC VERIFIED EMAIL (server-side write)
  // ═══════════════════════════════════════════════

  Future<AuthResult> syncVerifiedEmail() async {
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('syncVerifiedEmail');
      await callable.call();
      return AuthResult(
        success: true,
        message: 'Verification synced.',
      );
    } on FirebaseFunctionsException catch (e) {
      String message;
      switch (e.code) {
        case 'failed-precondition':
          message = 'The email has not been verified yet.';
          break;
        case 'unauthenticated':
          message = 'Please log in again.';
          break;
        default:
          message = e.message ?? 'Failed to sync verification.';
      }
      return AuthResult(success: false, message: message);
    } catch (e) {
      return AuthResult(success: false, message: 'Error: $e');
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
      debugPrint('getCurrentUserProfile error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════
  // LOGIN — does NOT sign out on unverified
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

      // ⭐ Reload to get latest emailVerified
      await firebaseUser.reload();
      final refreshed = _auth.currentUser;
      if (refreshed == null) {
        return AuthResult(
            success: false, message: 'Session error. Please try again.');
      }

      // ⭐ Fetch Firestore (authoritative for is_verified, role, etc.)
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) {
        await _auth.signOut();
        return AuthResult(
          success: false,
          message: 'User profile not found. Contact admin.',
        );
      }

      final data = doc.data()!;
      final role = (data['role'] ?? '').toString().toLowerCase();
      final isAdmin = role == 'admin';
      final isVerifiedFs = data['is_verified'] == true;

      // ⭐ Admin bypasses verification
      // ⭐ Non-admin must be verified in Firebase Auth AND Firestore
      if (!isAdmin) {
        // Firebase Auth is the authority
        if (refreshed.emailVerified != true) {
          // Do NOT sign out — VerifyEmailScreen needs currentUser
          return AuthResult(
            success: false,
            message: 'EMAIL_NOT_VERIFIED',
          );
        }

        // If Firestore lags behind, sync it (safe)
        if (!isVerifiedFs) {
          final syncResult = await syncVerifiedEmail();
          if (!syncResult.success) {
            return AuthResult(
              success: false,
              message: 'EMAIL_NOT_VERIFIED',
            );
          }
        }
      }

      // ⭐ Re-fetch to get updated is_verified
      final updatedDoc =
      await _firestore.collection('users').doc(uid).get();
      final updatedData = updatedDoc.data() ?? data;

      final user = UserModel.fromJson({
        ...updatedData,
        'email': updatedData['email'] ?? refreshed.email ?? '',
      });

      final approvalStatus =
      (updatedData['approval_status'] ?? '').toString().toLowerCase();
      final isActive = updatedData['is_active'] == true;

      if (approvalStatus == 'rejected') {
        await _auth.signOut();
        return AuthResult(
          success: false,
          message: 'Your registration was rejected. '
              'Please contact ADSB support for more information.',
        );
      }

      if (!isActive) {
        // Keep session active — PendingApprovalScreen needs currentUser
        return AuthResult(success: true, user: user);
      }

      await SessionGuardService().registerSession();

      return AuthResult(success: true, user: user);
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this username or email.';
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
          message = 'Invalid credentials.';
          break;
        case 'invalid-email':
          message = 'Invalid email/username format.';
          break;
      }
      return AuthResult(success: false, message: message);
    } catch (e) {
      return AuthResult(success: false, message: 'Error: $e');
    }
  }

  // ═══════════════════════════════════════════════
  // REGISTER — EMAIL (writes is_verified: false)
  // ═══════════════════════════════════════════════

  Future<AuthResult> registerWithEmail({
    required String email,
    required String name,
    required String password,
    required String phone,
    required String remark,
  }) async {
    UserCredential? credential;

    try {
      final cleanEmail = email.trim().toLowerCase();
      final cleanName = name.trim();
      final cleanPhone = phone.trim();
      final cleanRemark = remark.trim();

      credential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final firebaseUser = credential.user!;
      final uid = firebaseUser.uid;

      await firebaseUser.getIdToken(true);

      final derivedUsername = cleanEmail.contains('@')
          ? cleanEmail.split('@').first
          : cleanEmail;

      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'username': derivedUsername,
        'email': cleanEmail,
        'name': cleanName,
        'phone': cleanPhone,
        'remark': cleanRemark,
        'role': 'owner',
        'company': null,
        'client_id': null,
        'client_name': null,
        'site_ids': <String>[],
        'is_active': false,
        'approval_status': 'pending',
        'is_verified': false,   // ⭐ REQUIRED for rules
        'registered_at': FieldValue.serverTimestamp(),
        'approved_at': null,
        'approved_by': null,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Send Firebase verification email
      try {
        await firebaseUser.sendEmailVerification();
      } catch (e) {
        debugPrint('Email verification send failed: $e');
      }

      final user = UserModel(
        email: cleanEmail,
        username: derivedUsername,
        name: cleanName,
        role: 'owner',
        phone: cleanPhone,
        remark: cleanRemark,
        isActive: false,
        isVerified: false,   // ⭐
        approvalStatus: 'pending',
        registeredAt: DateTime.now(),
      );

      debugPrint('✅ User registered: $cleanEmail ($uid)');
      return AuthResult(success: true, user: user);
    } on FirebaseAuthException catch (e) {
      String message = 'Registration failed';
      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered. Try logging in or '
              'use "Forgot password".';
          break;
        case 'weak-password':
          message = 'Password is too weak. Minimum 6 characters.';
          break;
        case 'invalid-email':
          message = 'The email address is not valid.';
          break;
      }
      return AuthResult(success: false, message: message);
    } on FirebaseException catch (e) {
      debugPrint('❌ Firestore error: ${e.code} ${e.message}');
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
      debugPrint('❌ Unknown error: $e');
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
  // REGISTER — USERNAME (legacy, trusted)
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
        'is_verified': true,   // ⭐ Legacy: trusted (no real email)
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
        isVerified: true,   // ⭐
        approvalStatus: 'pending',
        registeredAt: DateTime.now(),
      );

      debugPrint('✅ User created: $cleanUsername ($uid)');
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
      debugPrint('❌ Firestore error: ${e.code} ${e.message}');
      if (credential != null && credential.user != null) {
        try {
          await credential.user!.delete();
        } catch (_) {}
      }
      return AuthResult(
          success: false, message: 'Could not save your profile.');
    } catch (e) {
      debugPrint('❌ Unknown error: $e');
      if (credential != null && credential.user != null) {
        try {
          await credential.user!.delete();
        } catch (_) {}
      }
      return AuthResult(
          success: false, message: 'Could not save your profile.');
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
        return AuthResult(success: false, message: 'User UID is missing.');
      }
      if (newPassword.length < 6) {
        return AuthResult(
            success: false, message: 'Password must be at least 6 characters.');
      }

      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('adminResetPassword');

      await callable.call({
        'targetUid': uid,
        'newPassword': newPassword,
      });

      return AuthResult(
        success: true,
        message: 'Password reset successfully.',
      );
    } on FirebaseFunctionsException catch (e) {
      String message;
      switch (e.code) {
        case 'permission-denied':
          message = 'Only admins can reset passwords.';
          break;
        case 'invalid-argument':
          message = e.message ?? 'Invalid password.';
          break;
        case 'not-found':
          message = 'User not found. Check the UID and region.';
          break;
        default:
          message = e.message ?? 'Failed to reset password.';
      }
      return AuthResult(success: false, message: message);
    } catch (e) {
      return AuthResult(
          success: false, message: 'Error resetting password.');
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
            success: false, message: 'You must be logged in.');
      }
      if (user.email == null) {
        return AuthResult(
            success: false, message: 'Current account has no identifier.');
      }
      if (newPassword.length < 6) {
        return AuthResult(
            success: false,
            message: 'New password must be at least 6 characters.');
      }
      if (currentPassword == newPassword) {
        return AuthResult(
            success: false,
            message: 'New password must be different.');
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
              success: false, message: 'Current password is incorrect.');
        }
        if (e.code == 'too-many-requests') {
          return AuthResult(
              success: false,
              message: 'Too many attempts. Please wait a few minutes.');
        }
        return AuthResult(
            success: false, message: 'Could not verify current password.');
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
              success: false, message: 'New password is too weak.');
        }
        if (e.code == 'requires-recent-login') {
          return AuthResult(
              success: false,
              message: 'Please log out and log in again, then retry.');
        }
        return AuthResult(
            success: false, message: 'Could not update password.');
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
      debugPrint('Failed to delete FCM token: $e');
    }

    await SessionGuardService().clearSession();
    await AppNotificationListener().stop();
    await _auth.signOut();
  }
}