import 'package:cloud_firestore/cloud_firestore.dart';

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

  Future<List<Map<String, dynamic>>> getExternalUsers() async {
    final all = await getAllUsers();
    return all.where((u) {
      final role = u['role'];
      return role == 'client' || role == 'operator';
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getInternalTeam() async {
    final all = await getAllUsers();
    return all.where((u) {
      final role = u['role'];
      return role == 'adsb' || role == 'technician' || role == 'admin';
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