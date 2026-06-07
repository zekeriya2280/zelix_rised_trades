import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zelix_rised_trades/screens/building_shop_screen.dart';
import '../models/warehouse.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // ---- Warehouse Collection ----

  /// Saves or overwrites a warehouse document in the 'warehouses' collection
  /// using the warehouse's [id] as the document ID.
  Future<void> saveWarehouse(Warehouse warehouse) async {
    try {
      await firestore
          .collection('warehouses')
          .doc(warehouse.id)
          .set(warehouse.toMap());
      print('WAREHOUSE SAVED: ${warehouse.id}');
    } catch (e) {
      print('WAREHOUSE SAVE ERROR: $e');
    }
  }

  /// Retrieves a single warehouse document by [id].
  /// Returns `null` if the document does not exist.
  Future<Warehouse?> getWarehouse(String id) async {
    try {
      final doc =
          await firestore.collection('warehouses').doc(id).get();
      if (doc.exists) {
        return Warehouse.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('WAREHOUSE GET ERROR: $e');
      return null;
    }
  }

  /// Retrieves all warehouse documents from the 'warehouses' collection.
  Future<List<Warehouse>> getAllWarehouses() async {
    try {
      final snapshot = await firestore.collection('warehouses').get();
      return snapshot.docs
          .map((doc) => Warehouse.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('WAREHOUSE GET ALL ERROR: $e');
      return [];
    }
  }

  /// Deletes a warehouse document by [id].
  Future<void> deleteWarehouse(String id) async {
    try {
      await firestore.collection('warehouses').doc(id).delete();
      print('WAREHOUSE DELETED: $id');
    } catch (e) {
      print('WAREHOUSE DELETE ERROR: $e');
    }
  }

  /// Appends a stock-update log entry to the warehouse document's `logs` array
  /// so existing logs are preserved on the server.
  Future<void> addWarehouseLog(
    String warehouseId,
    WarehouseLog log,
  ) async {
    try {
      await firestore
          .collection('warehouses')
          .doc(warehouseId)
          .update({
        'logs': FieldValue.arrayUnion([log.toMap()]),
      });
      print('WAREHOUSE LOG ADDED: $warehouseId');
    } catch (e) {
      print('WAREHOUSE LOG ERROR: $e');
    }
  }

  /// Replaces the whole stock map of a warehouse. Use this to persist
  /// the latest inventory state after any add/remove operations.
  Future<void> updateWarehouseStock(
    String warehouseId,
    Map<String, int> stockMap,
  ) async {
    try {
      await firestore
          .collection('warehouses')
          .doc(warehouseId)
          .update({'stock': stockMap});
      print('WAREHOUSE STOCK UPDATED: $warehouseId');
    } catch (e) {
      print('WAREHOUSE STOCK UPDATE ERROR: $e');
    }
  }
  Future<void> updatePurchasedBuildings(
    Building building,
  ) async {
    try {
      await firestore.collection('purchases').doc("${building.name}").set({
      'building': building.name,
      'cost': building.cost,
      'count': building.count,
      'timestamp': (DateTime.now().toUtc().hour+9).toString() + ":" + DateTime.now().minute.toString() + ":" + 
                   DateTime.now().second.toString() + "           " + DateTime.now().day.toString() + "/" + 
                   DateTime.now().month.toString() + "/" + DateTime.now().year.toString(),
    });
      print('PURCHASE LOGGED: ${building.name}');
    } catch (e) {
      print('WAREHOUSE CAPACITY UPDATE ERROR: $e');
    }
  }
  Future<List<Map<String, dynamic>>> getAllPurchases() async {
    try {
      final snapshot = await firestore.collection('purchases').get();
      return snapshot.docs
          .map((doc) => doc.data())
          .toList();
    } catch (e) {
      print('PURCHASES GET ALL ERROR: $e');
      return [];
    }
  }


  /// Generic activity logger
  Future<void> logToFirestore(String message) async {
    try {
      final doc = await firestore.collection('activity_logs').add({
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('SUCCESS: ${doc.id}');
    } catch (e) {
      print('FIRESTORE ERROR: $e');
    }
  }
}
