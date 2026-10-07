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
}
