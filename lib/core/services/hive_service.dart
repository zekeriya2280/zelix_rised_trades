import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zelix_rised_trades/core/models/building.dart';
import 'package:zelix_rised_trades/core/models/factory.dart';
import 'package:zelix_rised_trades/core/models/player.dart';
import 'package:zelix_rised_trades/core/models/warehouse.dart';

/// Singleton service that manages all game data using Hive local storage.
/// Replaces the previous FirestoreService entirely.
class HiveService {
  static final HiveService _instance = HiveService._internal();
  factory HiveService() => _instance;
  HiveService._internal();

  static const String _playerBox = 'player_box';
  static const String _warehousesBox = 'warehouses_box';
  static const String _factoriesBox = 'factories_box';
  static const String _purchasesBox = 'purchases_box';

  bool _initialized = false;

  /// Must be called once before any other methods (e.g. in main).
  Future<void> init() async {
    if (_initialized) return;
    await Hive.openBox(_playerBox);
    await Hive.openBox(_warehousesBox);
    await Hive.openBox(_factoriesBox);
    await Hive.openBox(_purchasesBox);
    _initialized = true;
    debugPrint('[HIVESERVICE] HIVE SERVICE INITIALIZED');
  }

  Box get _player => Hive.box(_playerBox);
  Box get _warehouses => Hive.box(_warehousesBox);
  Box get _factories => Hive.box(_factoriesBox);
  Box get _purchases => Hive.box(_purchasesBox);

  // ==================== PLAYER ====================

  Future<void> savePlayer(Player player) async {
    await _player.put('main', jsonEncode(player.toMap()));
    debugPrint('[HIVESERVICE] PLAYER SAVED TO HIVE: ¥${player.money}');
  }

  Player? getPlayer() {
    final raw = _player.get('main');
    if (raw == null) return null;
    return Player.fromMap(jsonDecode(raw));
  }

  // ==================== WAREHOUSES ====================

  Future<void> saveWarehouse(Warehouse warehouse) async {
    await _warehouses.put(warehouse.id, jsonEncode(warehouse.toMap()));
    debugPrint('[HIVESERVICE] WAREHOUSE SAVED TO HIVE: ${warehouse.id}');
  }

  Warehouse? getWarehouse(String id) {
    final raw = _warehouses.get(id);
    if (raw == null) return null;
    return Warehouse.fromMap(jsonDecode(raw));
  }

  List<Warehouse> getAllWarehouses() {
    return _warehouses.values.map((raw) {
      return Warehouse.fromMap(jsonDecode(raw));
    }).toList();
  }

  Future<void> deleteWarehouse(String id) async {
    await _warehouses.delete(id);
    debugPrint('[HIVESERVICE] WAREHOUSE DELETED FROM HIVE: $id');
  }

  Future<void> updateWarehouseStock(
    String warehouseId,
    Map<String, int> stockMap,
  ) async {
    final warehouse = getWarehouse(warehouseId);
    if (warehouse == null) return;
    // stockMap keys are resource names, convert back to ResourceType
    for (final entry in stockMap.entries) {
      final resourceType = warehouse.stock.keys.cast<dynamic>().firstWhere(
        (r) => r.toString().split('.').last == entry.key,
        orElse: () => warehouse.stock.keys.first,
      );
      if (resourceType != null) {
        warehouse.stock[resourceType] = entry.value;
      }
    }
    await saveWarehouse(warehouse);
    debugPrint('[HIVESERVICE] WAREHOUSE STOCK UPDATED IN HIVE: $warehouseId');
  }

  // ==================== BUILDING PURCHASES ====================

  Future<void> updatePurchasedBuildings(Building building) async {
    await _purchases.put(
      building.name,
      jsonEncode({
        'building': building.name,
        'cost': building.cost,
        'count': building.count,
      }),
    );
    debugPrint(
      '[HIVESERVICE] PURCHASE LOGGED TO HIVE: ${building.name} x${building.count}',
    );
  }

  /// Saves just the building name and count (used by SaveSystem without Building object)
  Future<void> savePurchasedBuildingData(String name, int count) async {
    await _purchases.put(
      name,
      jsonEncode({'building': name, 'cost': 0, 'count': count}),
    );
  }

  List<Map<String, dynamic>> getAllPurchases() {
    return _purchases.values.map((raw) {
      return jsonDecode(raw) as Map<String, dynamic>;
    }).toList();
  }

  // ==================== FACTORIES ====================

  Future<void> saveFactory(Factory factory) async {
    await _factories.put(factory.id, jsonEncode(factory.toMap()));
    debugPrint('[HIVESERVICE] FACTORY SAVED TO HIVE: ${factory.id}');
  }

  List<Factory> getAllFactories() {
    return _factories.values.map((raw) {
      return Factory.fromMap(jsonDecode(raw));
    }).toList();
  }

  Future<void> deleteFactory(String id) async {
    await _factories.delete(id);
    debugPrint('[HIVESERVICE] FACTORY DELETED FROM HIVE: $id');
  }

  // ==================== RESET ====================

  Future<void> resetAll() async {
    await _factories.clear();
    await _purchases.clear();
    await _warehouses.clear();
    await _player.put(
      'main',
      jsonEncode({'nickname': 'Player', 'money': 10000000}),
    );
    debugPrint(
      '[HIVESERVICE] HIVE RESET COMPLETE - All data cleared, player reset to ¥100000',
    );
  }

  // ==================== PRINT HIVE STATE ====================

  /// Prints the entire Hive database state to the console.
  /// Call this after purchases or any state change to see the current data.
  void printHiveState() {
    debugPrint('[HIVESERVICE] ');
    debugPrint('[HIVESERVICE] ═══════════════════════════════════════════');
    debugPrint('[HIVESERVICE]            HIVE DATABASE STATE');
    debugPrint('[HIVESERVICE] ═══════════════════════════════════════════');

    // Player
    final playerRaw = _player.get('main');
    if (playerRaw != null) {
      final player = Player.fromMap(jsonDecode(playerRaw));
      debugPrint(
        '[HIVESERVICE] 📋 PLAYER: ${player.nickname} | Money: ¥${player.money}',
      );
    } else {
      debugPrint('[HIVESERVICE] 📋 PLAYER: No player data');
    }

    // Purchases
    debugPrint('[HIVESERVICE] ');
    debugPrint('[HIVESERVICE] 📦 BUILDING PURCHASES:');
    final purchases = getAllPurchases();
    if (purchases.isEmpty) {
      debugPrint('[HIVESERVICE]    (empty)');
    } else {
      for (final p in purchases) {
        debugPrint(
          '[HIVESERVICE]    - ${p['building']}: count=${p['count']}, cost=¥${p['cost']}',
        );
      }
    }

    // Factories
    debugPrint('[HIVESERVICE] ');
    debugPrint('[HIVESERVICE] 🏭 FACTORIES:');
    final factories = getAllFactories();
    if (factories.isEmpty) {
      debugPrint('[HIVESERVICE]    (empty)');
    } else {
      for (final f in factories) {
        debugPrint(
          '[HIVESERVICE]   - ${f.id}: type=${f.type.name}, active=${f.active}, efficiency=${f.efficiency}',
        );
      }
    }

    // Warehouses
    debugPrint('[HIVESERVICE] ');
    debugPrint('[HIVESERVICE] 🏬 WAREHOUSES:');
    final warehouses = getAllWarehouses();
    if (warehouses.isEmpty) {
      debugPrint('[HIVESERVICE]    (empty)');
    } else {
      for (final w in warehouses) {
        debugPrint(
          '[HIVESERVICE]    - ${w.id} (${w.name}): capacity=${w.capacity}',
        );
        for (final entry in w.stock.entries) {
          debugPrint('[HIVESERVICE]        ${entry.key.name}: ${entry.value}');
        }
        debugPrint('[HIVESERVICE]        Logs: ${w.logs.length} entries');
      }
    }

    debugPrint('[HIVESERVICE] ═══════════════════════════════════════════');
    debugPrint('[HIVESERVICE] ');
  }
}
