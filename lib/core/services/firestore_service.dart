import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zelix_rised_trades/core/models/building.dart';
import '../models/factory.dart';
import '../models/player.dart';
import '../models/warehouse.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  static bool _firebaseAvailable = false;

  /// Call this once after Firebase.initializeApp() succeeds.
  static void markFirebaseAvailable() {
    _firebaseAvailable = true;
  }

  /// Returns true if Firebase was successfully initialized.
  static bool get isFirebaseAvailable => _firebaseAvailable;

  /// Helper that throws immediately if Firebase is not available,
  /// so callers can catch and fallback to empty data instead of hanging.
  void _checkFirebase() {
    if (!_firebaseAvailable) {
      throw Exception('Firebase is not available');
    }
  }

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // ---- Player Collection ----

  Future<void> savePlayer(Player player) async {
    _checkFirebase();
    try {
      await firestore.collection('player').doc('main').set(player.toMap());
      print('PLAYER SAVED');
    } catch (e) {
      print('PLAYER SAVE ERROR: $e');
    }
  }

  Future<Player?> getPlayer() async {
    try {
      final doc = await firestore.collection('player').doc('main').get();
      if (doc.exists) {
        return Player.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('PLAYER GET ERROR: $e');
      return null;
    }
  }

  // ---- Warehouse Collection ----

  /// Saves or overwrites a warehouse document in the 'warehouses' collection
  /// using the warehouse's [id] as the document ID.
  Future<void> saveWarehouse(Warehouse warehouse) async {
    _checkFirebase();
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

  /// Streams a single warehouse document by [id] in real time.
  /// Emits a new [Warehouse] whenever the document changes.
  Stream<Warehouse?> warehouseStream(String id) {
    return firestore
        .collection('warehouses')
        .doc(id)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return Warehouse.fromMap(snapshot.data()!);
      }
      return null;
    });
  }

  /// Retrieves all warehouse documents from the 'warehouses' collection.
  Future<List<Warehouse>> getAllWarehouses() async {
    _checkFirebase();
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

  // ---- Building Purchases Collection ----

  Future<void> updatePurchasedBuildings(
    Building building,
  ) async {
    try {
      await firestore.collection('buildings').doc(building.name).set({
      'building': building.name,
      'cost': building.cost,
      'count': building.count,
      'timestamp': FieldValue.serverTimestamp(),
    });
      print('PURCHASE LOGGED: ${building.name}');
    } catch (e) {
      print('PURCHASE UPDATE ERROR: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllPurchases() async {
    _checkFirebase();
    try {
      final snapshot = await firestore.collection('buildings').get();
      return snapshot.docs
          .map((doc) => doc.data())
          .toList();
    } catch (e) {
      print('PURCHASES GET ALL ERROR: $e');
      return [];
    }
  }

  // ---- Factory Collection ----

  /// Saves or overwrites a factory document in the 'factories' collection
  /// using the factory's [id] as the document ID.
  Future<void> saveFactory(Factory factory) async {
    try {
      await firestore
          .collection('factories')
          .doc(factory.id)
          .set(factory.toMap());
      print('FACTORY SAVED: ${factory.id}');
    } catch (e) {
      print('FACTORY SAVE ERROR: $e');
    }
  }

  /// Retrieves all factory documents from the 'factories' collection.
  Future<List<Factory>> getAllFactories() async {
    _checkFirebase();
    try {
      final snapshot = await firestore.collection('factories').get();
      return snapshot.docs
          .map((doc) => Factory.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('FACTORIES GET ALL ERROR: $e');
      return [];
    }
  }

  /// Deletes a factory document by [id].
  Future<void> deleteFactory(String id) async {
    try {
      await firestore.collection('factories').doc(id).delete();
      print('FACTORY DELETED: $id');
    } catch (e) {
      print('FACTORY DELETE ERROR: $e');
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

  /// Resets all game data: only the player collection remains.
  /// Deletes all factories, buildings purchases, and warehouses.
  Future<void> resetAll() async {
    _checkFirebase();
    try {
      // Delete all factories
      final factoriesSnapshot = await firestore.collection('factories').get();
      for (final doc in factoriesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete all building purchases
      final buildingsSnapshot = await firestore.collection('buildings').get();
      for (final doc in buildingsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete all warehouses
      final warehousesSnapshot = await firestore.collection('warehouses').get();
      for (final doc in warehousesSnapshot.docs) {
        await doc.reference.delete();
      }

      print('FIREBASE RESET COMPLETE - Player data preserved');
    } catch (e) {
      print('FIREBASE RESET ERROR: $e');
    }
  }
}