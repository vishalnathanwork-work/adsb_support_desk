import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/localized_preset.dart';

class PresetService {
  final _col = FirebaseFirestore.instance.collection('presets');

  // ═══════════════════════════════════════════════════════════
  // READ
  // ═══════════════════════════════════════════════════════════

  Future<List<LocalizedPreset>> getProductTypes() async {
    try {
      final doc = await _col.doc('product_types').get();
      if (!doc.exists) return [];
      final items = doc.data()!['items'];
      if (items is! List) return [];
      return items.map(LocalizedPreset.fromJson).toList();
    } catch (e) {
      print('getProductTypes error: $e');
      return [];
    }
  }

  Future<Map<String, List<LocalizedPreset>>> getProductIssues() async {
    try {
      final doc = await _col.doc('product_issues').get();
      if (!doc.exists) return {};
      final items = doc.data()!['items'];
      if (items is! Map) return {};

      final result = <String, List<LocalizedPreset>>{};
      items.forEach((productKey, value) {
        if (value is List) {
          result[productKey.toString()] =
              value.map(LocalizedPreset.fromJson).toList();
        }
      });
      return result;
    } catch (e) {
      print('getProductIssues error: $e');
      return {};
    }
  }

  Future<List<LocalizedPreset>> getRootCauses() async {
    try {
      final doc = await _col.doc('root_causes').get();
      if (!doc.exists) return [];
      final items = doc.data()!['items'];
      if (items is! List) return [];
      return items.map(LocalizedPreset.fromJson).toList();
    } catch (e) {
      print('getRootCauses error: $e');
      return [];
    }
  }

  Future<List<LocalizedPreset>> getSolutions() async {
    try {
      final doc = await _col.doc('solutions').get();
      if (!doc.exists) return [];
      final items = doc.data()!['items'];
      if (items is! List) return [];
      return items.map(LocalizedPreset.fromJson).toList();
    } catch (e) {
      print('getSolutions error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // WRITE
  // ═══════════════════════════════════════════════════════════

  Future<bool> saveProductTypes(List<LocalizedPreset> items) async {
    try {
      await _col.doc('product_types').set({
        'items': items.map((i) => i.toJson()).toList(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('saveProductTypes error: $e');
      return false;
    }
  }

  Future<bool> saveProductIssues(
      Map<String, List<LocalizedPreset>> items) async {
    try {
      final map = <String, dynamic>{};
      items.forEach((key, list) {
        map[key] = list.map((i) => i.toJson()).toList();
      });
      await _col.doc('product_issues').set({
        'items': map,
        'updated_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('saveProductIssues error: $e');
      return false;
    }
  }

  Future<bool> saveRootCauses(List<LocalizedPreset> items) async {
    try {
      await _col.doc('root_causes').set({
        'items': items.map((i) => i.toJson()).toList(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('saveRootCauses error: $e');
      return false;
    }
  }

  Future<bool> saveSolutions(List<LocalizedPreset> items) async {
    try {
      await _col.doc('solutions').set({
        'items': items.map((i) => i.toJson()).toList(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('saveSolutions error: $e');
      return false;
    }
  }
}