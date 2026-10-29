import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'notification_service.dart';

class UserService {
  final _col = FirebaseFirestore.instance.collection('users');

  // ═══════════════════════════════════════════════
  // READ
  // ═══════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final snap = await _col.get();
      final list = snap.docs
          .map((d) => <String, dynamic>{'uid': d.id, ...d.data()})
          .toList();
      list.sort((a, b) => (a['name'] ?? '')
          .toString()
          .compareTo((b['name'] ?? '').toString()));
      return list;
    } catch (e) {
      print('getAllUsers error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getExternalUsers() async {
    final all = await getAllUsers();
    return all.where((u) {
      final role = u['role'];
      return role == 'owner' || role == 'operator';
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getInternalTeam() async {
    final all = await getAllUsers();
    return all.where((u) {
      final role = u['role'];
      return role == 'adsb' ||
          role == 'technician' ||
          role == 'onsite' ||
          role == 'admin';
    }).toList();
  }

  Future<Map<String, dynamic>?> getUserByUid(String uid) async {
    try {
      final doc = await _col.doc(uid).get();
      if (!doc.exists) return null;
      return <String, dynamic>{'uid': doc.id, ...doc.data()!};
    } catch (e) {
      print('getUserByUid error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getFreshUserByUid(String uid) async {
    try {
      final doc = await _col.doc(uid).get();
      if (!doc.exists) return null;
      return <String, dynamic>{'uid': doc.id, ...doc.data()!};
    } catch (e) {
      print('getFreshUserByUid error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════
  // REGISTRATION / APPROVAL
  // ═══════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getPendingUsers() async {
    try {
      final snap = await _col
          .where('approval_status', isEqualTo: 'pending')
          .where('is_verified', isEqualTo: true)   // ⭐ FILTER
          .get();
      final list = snap.docs
          .map((d) => <String, dynamic>{'uid': d.id, ...d.data()})
          .toList();
      list.sort((a, b) {
        final aTime = a['registered_at'];
        final bTime = b['registered_at'];
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        try {
          return (bTime as dynamic).toDate().compareTo((aTime as dynamic).toDate());
        } catch (_) {
          return 0;
        }
      });
      return list;
    } catch (e) {
      print('getPendingUsers error: $e');
      return [];
    }
  }

  Future<int> getPendingUsersCount() async {
    try {
      final snap = await _col
          .where('approval_status', isEqualTo: 'pending')
          .where('is_verified', isEqualTo: true)   // ⭐ FILTER
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      print('getPendingUsersCount error: $e');
      return 0;
    }
  }

  Stream<List<Map<String, dynamic>>> streamPendingUsers() {
    return _col
        .where('approval_status', isEqualTo: 'pending')
        .where('is_verified', isEqualTo: true)   // ⭐ FILTER
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((d) => <String, dynamic>{'uid': d.id, ...d.data()})
          .toList();
      list.sort((a, b) {
        final aTime = a['registered_at'];
        final bTime = b['registered_at'];
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        try {
          return (bTime as dynamic).toDate().compareTo((aTime as dynamic).toDate());
        } catch (_) {
          return 0;
        }
      });
      return list;
    });
  }

  Future<bool> approveUser({
    required String uid,
    required String clientId,
    required String clientName,
    required List<String> siteIds,
    required String adminEmail,
    required String role,
  }) async {
    try {
      if (role != 'owner' && role != 'operator') {
        print('approveUser error: invalid role "$role"');
        return false;
      }
      if (role == 'operator' && siteIds.length != 1) {
        print('approveUser error: operator must have exactly 1 site');
        return false;
      }
      if (role == 'owner' && siteIds.isEmpty) {
        print('approveUser error: owner must have at least 1 site');
        return false;
      }

      final userDoc = await _col.doc(uid).get();
      final userData = userDoc.data();

      // ⭐ BLOCK APPROVING UNVERIFIED USERS
      if (userData?['is_verified'] != true) {
        print('approveUser error: user is not verified');
        return false;
      }

      final userEmail = userData?['email'] as String? ?? '';
      final userName = userData?['name'] as String? ?? 'User';

      await _col.doc(uid).update({
        'is_active': true,
        'approval_status': 'approved',
        'role': role,
        'client_id': clientId,
        'client_name': clientName,
        'company': clientName,
        'site_ids': siteIds,
        'approved_at': FieldValue.serverTimestamp(),
        'approved_by': adminEmail,
        'updated_at': FieldValue.serverTimestamp(),
      });

      try {
        await NotificationService().onUserApproved(
          userEmail: userEmail,
          userName: userName,
        );
      } catch (e) {
        print('onUserApproved notification failed: $e');
      }

      print('✅ User approved: $userEmail as $role');
      return true;
    } catch (e) {
      print('approveUser error: $e');
      return false;
    }
  }

  Future<bool> rejectUser(String uid) async {
    try {
      final userDoc = await _col.doc(uid).get();
      final userEmail = userDoc.data()?['email'] as String? ?? '';
      final userName = userDoc.data()?['name'] as String? ?? 'User';

      try {
        await NotificationService().onUserRejected(
          userEmail: userEmail,
          userName: userName,
        );
      } catch (e) {
        print('onUserRejected notification failed: $e');
      }

      await _col.doc(uid).delete();
      return true;
    } catch (e) {
      print('rejectUser error: $e');
      return false;
    }
  }

// ═══════════════════════════════════════════════
// ADMIN — CREATE USER (Cloud Function)
// ═══════════════════════════════════════════════

  Future<({String? uid, String? error})> adminCreateUser({
    required String email,
    required String password,
    required String name,
    required String role,
    String? phone,
    String? clientId,
    String? clientName,
    List<String> siteIds = const [],
  }) async {
    try {
      // ⭐ MUST use asia-southeast1 — matches the Cloud Function's region
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('adminCreateUser');

      final result = await callable.call({
        'email': email,
        'password': password,
        'name': name,
        'role': role,
        'phone': phone,
        'clientId': clientId,
        'clientName': clientName,
        'siteIds': siteIds,
      });

      final uid = result.data['uid'] as String?;
      if (uid == null || uid.isEmpty) {
        return (uid: null, error: 'Server did not return a user ID.');
      }
      return (uid: uid, error: null);
    } on FirebaseFunctionsException catch (e) {
      print('adminCreateUser FAILED: code=${e.code}, message=${e.message}');

      String message;
      switch (e.code) {
        case 'not-found':
          message = 'Cloud Function not found. Deploy adminCreateUser to '
              'asia-southeast1, then try again.';
          break;
        case 'unauthenticated':
          message = 'You must be signed in to create users.';
          break;
        case 'permission-denied':
          message = 'Only administrators can create users.';
          break;
        case 'already-exists':
          message = 'This email is already registered. Use a different email.';
          break;
        case 'invalid-argument':
          message = e.message ?? 'Invalid input. Check email and password.';
          break;
        case 'internal':
          message = e.message ?? 'Server error. Please try again.';
          break;
        case 'unavailable':
          message = 'Network error. Check your connection.';
          break;
        default:
          message = e.message ?? 'Failed to create user (${e.code}).';
      }
      return (uid: null, error: message);
    } catch (e) {
      print('adminCreateUser unexpected error: $e');
      return (uid: null, error: 'Unexpected error: $e');
    }
  }

  // ═══════════════════════════════════════════════
  // UPDATE
  // ═══════════════════════════════════════════════

  Future<bool> updateUser({
    required String uid,
    required Map<String, dynamic> fields,
  }) async {
    try {
      await _col.doc(uid).update({
        ...fields,
        'updated_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('updateUser error: $e');
      return false;
    }
  }

  Future<bool> deactivateUser(String uid) async {
    return updateUser(uid: uid, fields: {'is_active': false});
  }

  Future<bool> reactivateUser(String uid) async {
    return updateUser(uid: uid, fields: {'is_active': true});
  }

  Future<bool> changeRole(String uid, String newRole) async {
    return updateUser(uid: uid, fields: {'role': newRole});
  }

  Future<bool> updateSites(String uid, List<String> siteIds) async {
    return updateUser(uid: uid, fields: {'site_ids': siteIds});
  }

  // ═══════════════════════════════════════════════
  // DELETE (Firestore only — Cloud Function handles Auth)
  // ═══════════════════════════════════════════════

  Future<bool> deleteUser(String uid) async {
    try {
      // Get email for FCM token cleanup
      final userDoc = await _col.doc(uid).get();
      final email = userDoc.data()?['email'] as String? ?? '';

      // Delete FCM token
      if (email.isNotEmpty) {
        final safeKey = email.replaceAll('.', '_');
        try {
          await FirebaseFirestore.instance
              .collection('fcm_tokens')
              .doc(safeKey)
              .delete();
        } catch (e) {
          print('FCM token delete error: $e');
        }
      }

      // Delete Firestore doc
      // → Triggers cleanupAuthOnUserDelete Cloud Function
      // → Which deletes Firebase Auth account
      await _col.doc(uid).delete();

      print('✅ User deleted from Firestore (Auth cleanup in progress)');
      return true;
    } catch (e) {
      print('deleteUser error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════
  // STATS
  // ═══════════════════════════════════════════════

  Future<Map<String, int>> getUserTicketStats(String email) async {
    try {
      final created = await FirebaseFirestore.instance
          .collection('tickets')
          .where('created_by', isEqualTo: email)
          .count()
          .get();

      final assigned = await FirebaseFirestore.instance
          .collection('tickets')
          .where('assigned_to', isEqualTo: email)
          .count()
          .get();

      return {
        'created': created.count ?? 0,
        'assigned': assigned.count ?? 0,
      };
    } catch (e) {
      print('getUserTicketStats error: $e');
      return {'created': 0, 'assigned': 0};
    }
  }
}