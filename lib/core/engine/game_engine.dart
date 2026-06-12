import 'dart:async';

import 'package:flutter/foundation.dart';

import '../enums/factory_type.dart';
import '../models/factory.dart' as models;
import '../models/player.dart';
import '../models/warehouse.dart';
import '../services/hive_service.dart';

/// Singleton game engine that:
/// - Ticks every 1 second
/// - Reads factories, warehouses & player from Hive local storage
/// - Runs auto-production logic on each tick
/// - Deducts upkeep cost from player money per production cycle
/// - Saves production results back to Hive
/// - Exposes reactive notifiers for UI widgets to consume
class GameEngine {
  // ---- Singleton ----
  static final GameEngine _instance = GameEngine._internal();
  factory GameEngine() => _instance;
  GameEngine._internal();

  // ---- Services ----
  final HiveService _hive = HiveService();

  // ---- Timer ----
  Timer? _timer;

  // ---- Reactive state ----

  /// Holds the latest list of factories, refreshed from Hive on each tick.
  final ValueNotifier<List<models.Factory>> factoriesNotifier =
      ValueNotifier<List<models.Factory>>([]);

  /// Holds the latest warehouse map keyed by warehouse ID.
  final ValueNotifier<Map<String, Warehouse>> warehousesNotifier =
      ValueNotifier<Map<String, Warehouse>>({});

  /// Holds the latest player data from Hive.
  final ValueNotifier<Player> playerNotifier =
      ValueNotifier<Player>(Player(nickname: 'Player', money: 100000));

  /// Fires every 1-second tick (even when no production occurs).
  /// UI screens can listen to this to update progress sliders etc.
  final ValueNotifier<int> tickNotifier = ValueNotifier<int>(0);

  /// Whether the engine is currently running.
  bool _running = false;
  bool get isRunning => _running;

  // ---- Lifecycle ----

  /// Starts the engine: loads data from Hive and begins the 1s tick.
  void start() {
    if (_running) return;
    _running = true;

    debugPrint('[GameEngine] Starting...');

    // Load initial data from Hive
    _loadFromHive();

    // Start the 1-second production tick
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tick();
    });

    debugPrint('[GameEngine] Started.');
  }

  /// Reload all game state from Hive storage.
  void _loadFromHive() {
    // Load player
    final player = _hive.getPlayer();
    if (player != null) {
      playerNotifier.value = player;
    }

    // Load factories
    factoriesNotifier.value = _hive.getAllFactories();

    // Load warehouses
    final warehouses = _hive.getAllWarehouses();
    final warehouseMap = <String, Warehouse>{};
    for (final w in warehouses) {
      warehouseMap[w.id] = w;
    }
    warehousesNotifier.value = warehouseMap;
  }

  /// Stops the engine and cleans up.
  void stop() {
    if (!_running) return;
    _running = false;

    _timer?.cancel();
    _timer = null;

    debugPrint('[GameEngine] Stopped.');
  }

  // ---- Production tick ----

  /// Called every 1 second. Runs auto-production for all active factories
  /// and deducts upkeep costs from player money.
  void _tick() {
    // Notify UI listeners every second (for progress sliders etc.)
    tickNotifier.value++;

    // Re-load fresh data from Hive each tick
    _loadFromHive();

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
      final newMoney =
          (currentPlayer.money - totalUpkeepCost).clamp(0, 999999999);
      currentPlayer.money = newMoney;
      playerNotifier.value = currentPlayer; // triggers UI update
      _hive.savePlayer(currentPlayer);
    }

    if (anyProduced) {
      _saveFactories(factories);
      _saveAllWarehouses(warehouses);
    }
  }

  // ---- Persistence ----

  Future<void> _saveFactories(List<models.Factory> factories) async {
    for (final factory in factories) {
      await _hive.saveFactory(factory);
    }
  }

  Future<void> _saveAllWarehouses(Map<String, Warehouse> warehouses) async {
    for (final warehouse in warehouses.values) {
      await _hive.saveWarehouse(warehouse);
      await _hive.updateWarehouseStock(
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