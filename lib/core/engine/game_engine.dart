import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../enums/factory_type.dart';
import '../models/factory.dart' as models;
import '../models/player.dart';
import '../models/warehouse.dart';
import '../services/firestore_service.dart';

/// Singleton game engine that:
/// - Ticks every 1 second
/// - Streams factories, warehouses & player from Firebase snapshots (real-time)
/// - Runs auto-production logic on each tick
/// - Deducts upkeep cost from player money per production cycle
/// - Saves production results back to Firebase
/// - Exposes reactive notifiers for UI widgets to consume
class GameEngine {
  // ---- Singleton ----
  static final GameEngine _instance = GameEngine._internal();
  factory GameEngine() => _instance;
  GameEngine._internal();

  // ---- Services ----
  final FirestoreService _firestore = FirestoreService();

  // ---- Timer ----
  Timer? _timer;

  // ---- Firebase stream subscriptions ----
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _factoriesSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _warehousesSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _playerSubscription;

  // ---- Reactive state ----
  /// Holds the latest list of factories, rebuilt whenever Firebase data changes.
  final ValueNotifier<List<models.Factory>> factoriesNotifier =
      ValueNotifier<List<models.Factory>>([]);

  /// Holds the latest warehouse map keyed by warehouse ID.
  final ValueNotifier<Map<String, Warehouse>> warehousesNotifier =
      ValueNotifier<Map<String, Warehouse>>({});

  /// Holds the latest player data from Firebase in real-time.
  final ValueNotifier<Player> playerNotifier =
      ValueNotifier<Player>(Player(nickname: 'Player', money: 100000));

  /// Fires every 1-second tick (even when no production occurs).
  /// UI screens can listen to this to update progress sliders etc.
  final ValueNotifier<int> tickNotifier = ValueNotifier<int>(0);

  /// Whether the engine is currently running.
  bool _running = false;
  bool get isRunning => _running;

  // ---- Lifecycle ----

  /// Starts the engine: subscribes to Firebase snapshots and begins the 1s tick.
  void start() {
    if (_running) return;
    _running = true;

    debugPrint('[GameEngine] Starting...');

    if (FirestoreService.isFirebaseAvailable) {
      // Subscribe to factories collection snapshots (real-time)
      _factoriesSubscription = FirebaseFirestore.instance
          .collection('factories')
          .snapshots()
          .listen(_onFactoriesSnapshot);

      // Subscribe to all warehouses collection snapshots (real-time)
      _warehousesSubscription = FirebaseFirestore.instance
          .collection('warehouses')
          .snapshots()
          .listen(_onAllWarehousesSnapshot);

      // Subscribe to player document snapshot (real-time)
      _playerSubscription = FirebaseFirestore.instance
          .collection('player')
          .doc('main')
          .snapshots()
          .listen(_onPlayerSnapshot);
    }

    // Start the 1-second production tick
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tick();
    });

    debugPrint('[GameEngine] Started.');
  }

  /// Stops the engine and cleans up all subscriptions.
  void stop() {
    if (!_running) return;
    _running = false;

    _timer?.cancel();
    _timer = null;
    _factoriesSubscription?.cancel();
    _factoriesSubscription = null;
    _warehousesSubscription?.cancel();
    _warehousesSubscription = null;
    _playerSubscription?.cancel();
    _playerSubscription = null;

    debugPrint('[GameEngine] Stopped.');
  }

  // ---- Firebase snapshot handlers ----

  void _onFactoriesSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final factories = snapshot.docs.map((doc) {
      return models.Factory.fromMap(doc.data());
    }).toList();

    factoriesNotifier.value = factories;
  }

  /// Listens to the whole warehouses collection.
  void _onAllWarehousesSnapshot(
      QuerySnapshot<Map<String, dynamic>> snapshot) {
    final map = <String, Warehouse>{};
    for (final doc in snapshot.docs) {
      final warehouse = Warehouse.fromMap(doc.data());
      map[warehouse.id] = warehouse;
    }
    warehousesNotifier.value = map;
  }

  /// Listens to the player document in real-time.
  void _onPlayerSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    if (snapshot.exists) {
      final player = Player.fromMap(snapshot.data()!);
      playerNotifier.value = player;
    }
  }

  // ---- Production tick ----

  /// Called every 1 second. Runs auto-production for all active factories
  /// and deducts upkeep costs from player money.
  void _tick() {
    // Notify UI listeners every second (for progress sliders etc.)
    tickNotifier.value++;

    final factories = factoriesNotifier.value;
    if (factories.isEmpty) return;

    final warehouses = warehousesNotifier.value;
    if (warehouses.isEmpty) return;

    bool anyProduced = false;
    bool anyUpkeepDeducted = false;
    int totalUpkeepCost = 0;

    for (final factory in factories) {
      if (!factory.active) continue;

      // Determine which warehouse this factory uses.
      Warehouse? warehouse;
      final prefix = factory.id.split('_').first;
      if (warehouses.containsKey(prefix)) {
        warehouse = warehouses[prefix];
      } else if (warehouses.isNotEmpty) {
        warehouse = warehouses.values.first;
      }

      if (warehouse == null) continue;

      final elapsed =
          DateTime.now().difference(factory.lastProduction).inSeconds;
      if (elapsed < factory.type.productionSeconds) continue;

      // Check if enough input resources
      if (factory.type.input != null) {
        if (warehouse.get(factory.type.input!) < factory.type.inputAmount) {
          continue; // Skip if not enough input
        }
      }

      // --- UPKEEP: Deduct once per production cycle ---
      final upkeepElapsed =
          DateTime.now().difference(factory.lastUpkeepPaid).inSeconds;
      if (upkeepElapsed >= factory.type.productionSeconds) {
        factory.lastUpkeepPaid = DateTime.now();
        totalUpkeepCost += factory.type.upkeepCost;
        anyUpkeepDeducted = true;
      }

      // Run production
      factory.update(warehouse);
      anyProduced = true;
    }

    // Apply upkeep deductions to player money
    if (anyUpkeepDeducted && totalUpkeepCost > 0) {
      final currentPlayer = playerNotifier.value;
      final newMoney = (currentPlayer.money - totalUpkeepCost).clamp(0, 999999999);
      currentPlayer.money = newMoney;
      playerNotifier.value = currentPlayer; // triggers UI update
      _firestore.savePlayer(currentPlayer);
    }

    if (anyProduced) {
      _saveFactories(factories);
      _saveAllWarehouses(warehouses);
    }
  }

  // ---- Persistence ----

  Future<void> _saveFactories(List<models.Factory> factories) async {
    for (final factory in factories) {
      await _firestore.saveFactory(factory);
    }
  }

  Future<void> _saveAllWarehouses(Map<String, Warehouse> warehouses) async {
    for (final warehouse in warehouses.values) {
      await _firestore.saveWarehouse(warehouse);
      await _firestore.updateWarehouseStock(
        warehouse.id,
        warehouse.stock.map((key, value) => MapEntry(key.name, value)),
      );
    }
  }

  // ---- Cleanup ----
  void dispose() {
    stop();
    factoriesNotifier.dispose();
    warehousesNotifier.dispose();
    playerNotifier.dispose();
    tickNotifier.dispose();
  }
}