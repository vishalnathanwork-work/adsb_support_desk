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

  // ═══════════════════════════════════════════════
  // LOGIN
  // ═══════════════════════════════════════════════

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
      final user = UserModel.fromJson({
        ...data,
        'email': data['email'] ?? credential.user!.email ?? '',
      });

      // Pending approval — allow login, router redirects
      if (user.isPendingApproval) {
        return AuthResult(success: true, user: user);
      }

      // Rejected / deactivated
      if (!user.isActive) {
        await _auth.signOut();
        return AuthResult(
          success: false,
          message:
          'Your account has been deactivated. Please contact the administrator.',
        );
      }

      return AuthResult(success: true, user: user);
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

  // ═══════════════════════════════════════════════
  // REGISTER (self-signup)
  //
  // NOTE: Notification to admins is handled by
  // the Cloud Function notifyAdminsNewRegistration,
  // which triggers when the user doc is created.
  // Do NOT add client-side notification calls —
  // they will fail (rules block reading admin list)
  // and can create duplicates.
  // ═══════════════════════════════════════════════

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
    required List<String> siteIds,
    required String clientId,
    required String clientName,
  }) async {
    try {
      // 1. Create Auth user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final uid = credential.user!.uid;

      // 2. Create Firestore profile (pending, inactive)
      //    → This triggers notifyAdminsNewRegistration
      await _firestore.collection('users').doc(uid).set({
        'email': email.trim().toLowerCase(),
        'name': name.trim(),
        'role': role,
        'phone': phone.trim(),
        'company': clientName,
        'client_id': clientId,
        'client_name': clientName,
        'site_ids': siteIds,
        'is_active': false,
        'approval_status': 'pending',
        'registered_at': FieldValue.serverTimestamp(),
        'approved_at': null,
        'approved_by': null,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // 3. Build local model
      final user = UserModel(
        email: email.trim().toLowerCase(),
        name: name.trim(),
        role: role,
        phone: phone.trim(),
        company: clientName,
        clientId: clientId,
        clientName: clientName,
        siteIds: siteIds,
        isActive: false,
        approvalStatus: 'pending',
        registeredAt: DateTime.now(),
      );

      return AuthResult(success: true, user: user);
    } on FirebaseAuthException catch (e) {
      String message = 'Registration failed';
      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered.';
          break;
        case 'weak-password':
          message = 'Password is too weak.';
          break;
        case 'invalid-email':
          message = 'Invalid email format.';
          break;
      }
      return AuthResult(success: false, message: message);
    } catch (e) {
      return AuthResult(success: false, message: 'Error: $e');
    }
  }

  // ═══════════════════════════════════════════════
  // SIGN OUT
  // ═══════════════════════════════════════════════

  Future<void> logout() async {
    // Remove FCM token before signing out
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