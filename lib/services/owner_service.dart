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
}