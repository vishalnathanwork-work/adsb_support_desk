import 'package:cloud_firestore/cloud_firestore.dart';

class PresetService {
  final _col = FirebaseFirestore.instance.collection('presets');

  // ─── READ ───
  Future<List<String>> getProductTypes() => _getStringList('product_types');
  Future<List<String>> getProductIssues() => _getStringList('product_issues');
  Future<List<String>> getRootCauses() => _getStringList('root_causes');
  Future<List<String>> getSolutions() => _getStringList('solutions');

  Future<List<Map<String, String>>> getSites() async {
    try {
      final doc = await _col.doc('sites').get();
      if (!doc.exists) return [];
      final data = doc.data()!;
      final items = data['items'] as List? ?? [];
      return items
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
    } catch (e) {
      print('getSites error: $e');
      return [];
    }
  }

  Future<List<String>> _getStringList(String docId) async {
    try {
      final doc = await _col.doc(docId).get();
      if (!doc.exists) return [];
      final data = doc.data()!;
      return List<String>.from(data['items'] ?? []);
    } catch (e) {
      print('_getStringList($docId) error: $e');
      return [];
    }
  }

  // ─── WRITE ───
  Future<bool> saveProductTypes(List<String> items) =>
      _saveStringList('product_types', items);

  Future<bool> saveProductIssues(List<String> items) =>
      _saveStringList('product_issues', items);

  Future<bool> saveRootCauses(List<String> items) =>
      _saveStringList('root_causes', items);

  Future<bool> saveSolutions(List<String> items) =>
      _saveStringList('solutions', items);

  Future<bool> saveSites(List<Map<String, String>> items) async {
    try {
      await _col.doc('sites').set({
        'items': items,
        'updated_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('saveSites error: $e');
      return false;
    }
  }

  Future<bool> _saveStringList(String docId, List<String> items) async {
    try {
      await _col.doc(docId).set({
        'items': items,
        'updated_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('_saveStringList($docId) error: $e');
      return false;
    }
  }
}