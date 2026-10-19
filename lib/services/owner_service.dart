import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/client_model.dart';

class ClientService {
  final _col = FirebaseFirestore.instance.collection('clients');

  Future<List<ClientModel>> getAllClients() async {
    try {
      final snap = await _col.get();
      final list = snap.docs
          .map((d) => ClientModel.fromJson({...d.data(), 'id': d.id}))
          .toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    } catch (e) {
      print('getAllClients error: $e');
      return [];
    }
  }

  Future<ClientModel?> getClientById(String id) async {
    try {
      final doc = await _col.doc(id).get();
      if (!doc.exists) {
        print('⚠️ getClientById: doc not found for id = $id');
        return null;
      }
      final client = ClientModel.fromJson({...doc.data()!, 'id': doc.id});
      print('✅ getClientById: ${client.id} → ${client.name}');
      return client;
    } catch (e) {
      print('getClientById error: $e');
      return null;
    }
  }
  // ═══════════════════════════════════════════════
  // CREATE / UPDATE / DELETE
  // ═══════════════════════════════════════════════

  Future<bool> createClient(ClientModel client) async {
    try {
      if (client.id.isEmpty) {
        await _col.add(client.toJson());
      } else {
        await _col.doc(client.id).set(
          client.toJson(),
          SetOptions(merge: true),
        );
      }
      return true;
    } catch (e) {
      print('createClient error: $e');
      return false;
    }
  }

  Future<bool> updateClient(String clientId, Map<String, dynamic> fields) async {
    try {
      await _col.doc(clientId).update({
        ...fields,
        'updated_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('updateClient error: $e');
      return false;
    }
  }

  Future<bool> deleteClient(String clientId) async {
    try {
      await _col.doc(clientId).delete();
      return true;
    } catch (e) {
      print('deleteClient error: $e');
      return false;
    }
  }

  /// Count sites belonging to a client — used before delete.
  Future<int> countSitesForClient(String clientId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('sites')
          .where('client_id', isEqualTo: clientId)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      print('countSitesForClient error: $e');
      return 0;
    }
  }
}