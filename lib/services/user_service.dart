import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class UserService {
  final _col = FirebaseFirestore.instance.collection('users');

  // ═══════════════════════════════════════════════
  // READ
  // ═══════════════════════════════════════════════

  /// Returns all users as raw maps (includes uid).
  /// Each map has: uid, email, name, role, phone, company,
  /// is_active, site_ids, created_at, updated_at
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final snap = await _col.get();
      final list = snap.docs
          .map((d) => <String, dynamic>{'uid': d.id, ...d.data()})
          .toList();

      // Sort by name
      list.sort((a, b) =>
          (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));

      return list;
    } catch (e) {
      print('getAllUsers error: $e');
      return [];
    }
  }

  /// External users = clients + operators
  Future<List<Map<String, dynamic>>> getExternalUsers() async {
    final all = await getAllUsers();
    return all.where((u) {
      final role = u['role'];
      return role == 'owner' || role == 'operator';
    }).toList();
  }

  /// Internal team = adsb + technician + onsite + admin
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

  // ═══════════════════════════════════════════════
  // REGISTRATION / APPROVAL (NEW)
  // ═══════════════════════════════════════════════

  /// Returns all users with approval_status == 'pending'.
  /// Used by admin approval queue.
  Future<List<Map<String, dynamic>>> getPendingUsers() async {
    try {
      final snap = await _col
          .where('approval_status', isEqualTo: 'pending')
          .get();
      final list = snap.docs
          .map((d) => <String, dynamic>{'uid': d.id, ...d.data()})
          .toList();
      list.sort((a, b) {
        final aTime = a['registered_at'];
        final bTime = b['registered_at'];
        // Newest first
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        try {
          return (bTime as dynamic)
              .toDate()
              .compareTo((aTime as dynamic).toDate());
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

  /// Real-time stream of users with approval_status == 'pending'.
  Stream<List<Map<String, dynamic>>> streamPendingUsers() {
    return _col
        .where('approval_status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
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
          return (bTime as dynamic)
              .toDate()
              .compareTo((aTime as dynamic).toDate());
        } catch (_) {
          return 0;
        }
      });
      return list;
    });
  }

  /// Count of pending users — used for the badge on admin screens.
  Future<int> getPendingUsersCount() async {
    try {
      final snap = await _col
          .where('approval_status', isEqualTo: 'pending')
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      print('getPendingUsersCount error: $e');
      return 0;
    }
  }

  Future<bool> approveUser({
    required String uid,
    required String clientId,
    required String clientName,
    required List<String> siteIds,
    required String adminEmail,
  }) async {
    try {
      // Get user info first (for the notification)
      final userDoc = await _col.doc(uid).get();
      final userEmail = userDoc.data()?['email'] as String? ?? '';
      final userName = userDoc.data()?['name'] as String? ?? 'User';

      await _col.doc(uid).update({
        'is_active': true,
        'approval_status': 'approved',
        'client_id': clientId,
        'client_name': clientName,
        'site_ids': siteIds,
        'approved_at': FieldValue.serverTimestamp(),
        'approved_by': adminEmail,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // ✅ Notify the user
      try {
        await NotificationService().onUserApproved(
          userEmail: userEmail,
          userName: userName,
        );
      } catch (e) {
        print('onUserApproved notification failed: $e');
      }

      return true;
    } catch (e) {
      print('approveUser error: $e');
      return false;
    }
  }

  Future<bool> rejectUser(String uid) async {
    try {
      // Get user info BEFORE deleting
      final userDoc = await _col.doc(uid).get();
      final userEmail = userDoc.data()?['email'] as String? ?? '';
      final userName = userDoc.data()?['name'] as String? ?? 'User';

      // ✅ Notify BEFORE deleting (user can still see it if they log in)
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
  /// Re-read a single user doc — used by PendingApprovalScreen's refresh button.
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

  // ═══════════════════════════════════════════════
  // UPDATE (Option B — Firestore only, no Auth changes)
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

  /// Marks user inactive in Firestore.
  /// NOTE: In Option B, this does NOT disable their Auth account.
  /// They can still technically sign in, but AuthService will
  /// reject them at login because is_active == false.
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
  // STATS (used in admin screens)
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