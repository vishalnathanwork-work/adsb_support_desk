import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/site_model.dart';

class SiteService {
  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('sites');

  Future<List<SiteModel>> getSitesByClientId(String clientId) async {
    try {
      print('🔍 Querying sites with client_id = "$clientId"');
      final snap = await _col
          .where('client_id', isEqualTo: clientId)
          .get();
      print('   → found ${snap.docs.length} sites');

      final list = snap.docs
          .map((d) => SiteModel.fromJson({...d.data(), 'id': d.id}))
          .toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    } catch (e) {
      print('getSitesByClientId error: $e');
      return [];
    }
  }

  /// Get sites accessible to a user based on their siteIds list.
  /// If siteIds is empty, returns ALL active sites (e.g. for admin/ADSB/TT staff).
  Future<List<SiteModel>> getSitesForUser(List<String> siteIds) async {
    try {
      if (siteIds.isEmpty) {
        return await getAllActiveSites();
      }
      final snap = await _col.get();
      final list = snap.docs
          .where((d) => siteIds.contains(d.id))
          .map((d) => SiteModel.fromJson({...d.data(), 'id': d.id}))
          .toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    } catch (e) {
      print('getSitesForUser error: $e');
      return [];
    }
  }

  /// Fetch all active sites in system.
  Future<List<SiteModel>> getAllActiveSites() async {
    try {
      final snap = await _col.where('is_active', isEqualTo: true).get();
      final list = snap.docs
          .map((d) => SiteModel.fromJson({...d.data(), 'id': d.id}))
          .toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    } catch (e) {
      print('getAllActiveSites error: $e');
      return [];
    }
  }

  /// Fetch all sites (including inactive)
  Future<List<SiteModel>> getAllSites() async {
    try {
      final snap = await _col.get();
      final list = snap.docs
          .map((d) => SiteModel.fromJson({...d.data(), 'id': d.id}))
          .toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    } catch (e) {
      print('getAllSites error: $e');
      return [];
    }
  }

  /// Get single site by ID
  Future<SiteModel?> getSiteById(String siteId) async {
    try {
      final doc = await _col.doc(siteId).get();
      if (!doc.exists) return null;
      return SiteModel.fromJson({...doc.data()!, 'id': doc.id});
    } catch (e) {
      print('getSiteById error: $e');
      return null;
    }
  }

  /// Save or update a site
  Future<bool> saveSite(SiteModel site) async {
    try {
      if (site.id.isEmpty) {
        await _col.add(site.toJson());
      } else {
        await _col.doc(site.id).set(site.toJson(), SetOptions(merge: true));
      }
      return true;
    } catch (e) {
      print('saveSite error: $e');
      return false;
    }
  }

  /// Delete a site
  Future<bool> deleteSite(String siteId) async {
    try {
      await _col.doc(siteId).delete();
      return true;
    } catch (e) {
      print('deleteSite error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════
  // CREATE / UPDATE / DELETE (used by admin)
  // ═══════════════════════════════════════════════

  /// Create a new site. Returns the new doc ID, or null on failure.
  Future<String?> createSite(SiteModel site) async {
    try {
      final docRef = await _col.add({
        'client_id': site.clientId,
        'name': site.name,
        'address': site.address,
        'notes': site.notes,
        'zones': site.zones.map((z) => z.toJson()).toList(),
        'is_active': site.isActive,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      print('createSite error: $e');
      return null;
    }
  }

  /// Update an existing site.
  Future<bool> updateSite({
    required String siteId,
    required Map<String, dynamic> fields,
  }) async {
    try {
      await _col.doc(siteId).update({
        ...fields,
        'updated_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('updateSite error: $e');
      return false;
    }
  }

  /// Count tickets associated with a site — used before delete.
  Future<int> countTicketsForSite(String siteId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('tickets')
          .where('site_id', isEqualTo: siteId)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      print('countTicketsForSite error: $e');
      return 0;
    }
  }

  /// Count users assigned to a site — used before delete.
  Future<int> countUsersForSite(String siteId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('site_ids', arrayContains: siteId)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      print('countUsersForSite error: $e');
      return 0;
    }
  }
}
