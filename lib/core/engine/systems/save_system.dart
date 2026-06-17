import 'package:flutter/foundation.dart';

import '../../database/truck_db.dart';
import '../../models/city.dart';
import '../../models/player.dart';
import '../../models/route_model.dart';
import '../../models/truck.dart';
import '../../services/hive_service.dart';
import '../game_state.dart';
import 'i_system.dart';

/// Kayıt sistemi - Hive ile iletişim kuran tek sistem.
/// UI veya diğer sistemler HiveService'e direkt erişemez.
/// Sadece bu sistem üzerinden kayıt yapılır.
class SaveSystem extends ChangeNotifier implements ISystem {
  final HiveService _hive = HiveService();

  @override
  String get name => 'SaveSystem';

  DateTime? _lastSaveTime;
  DateTime? get lastSaveTime => _lastSaveTime;

  bool _autoSaveEnabled = true;
  bool get autoSaveEnabled => _autoSaveEnabled;

  int _saveInterval = 10;
  int _tickCounter = 0;

  @override
  void init(GameState state) {
    debugPrint('[SaveSystem] Initialized');
  }

  @override
  void update(GameState state) {
    if (!_autoSaveEnabled) return;

    _tickCounter++;
    if (_tickCounter >= _saveInterval) {
      _tickCounter = 0;
      save(state);
    }
  }

  Future<void> save(GameState state) async {
    try {
      await _hive.savePlayer(state.player);

      for (final factory in state.factories) {
        await _hive.saveFactory(factory);
      }

      for (final warehouse in state.warehouses) {
        await _hive.saveWarehouse(warehouse);
      }

      // Purchased buildings'leri Hive purchases_box'a kaydet
      for (final entry in state.purchasedBuildings.entries) {
        await _hive.savePurchasedBuildingData(entry.key, entry.value);
      }

      // Truckları kaydet
      await _hive.saveAllTrucks(state.trucks);

      _lastSaveTime = DateTime.now();
      debugPrint('[SaveSystem] Game saved at $_lastSaveTime');
    } catch (e) {
      debugPrint('[SaveSystem] Save failed: $e');
    }
  }

  GameState load() {
    debugPrint('[SaveSystem] Loading game state from Hive...');

    Player player;
    final savedPlayer = _hive.getPlayer();
    if (savedPlayer != null) {
      player = savedPlayer;
    } else {
      player = Player(nickname: 'Player', money: 10000000);
    }

    final warehouses = _hive.getAllWarehouses();
    final factories = _hive.getAllFactories();

    // Purchased building verilerini Hive'dan yükle
    final purchases = _hive.getAllPurchases();
    final purchasedBuildings = <String, int>{};
    for (final p in purchases) {
      final name = p['building'] as String?;
      final count = p['count'] as int?;
      if (name != null && count != null) {
        purchasedBuildings[name] = count;
      }
    }

    // Truckları yükle
    List<Truck> trucks;
    final savedTrucks = _hive.getAllTrucks();
    if (savedTrucks.isNotEmpty) {
      // Kayıtlı truck varsa onları yükle
      trucks = savedTrucks;
      debugPrint('[SaveSystem] Loaded ${trucks.length} trucks from save');
    } else {
      // Kayıt yoksa starter truck oluştur (initial state)
      trucks = _createInitialTrucks();
      debugPrint('[SaveSystem] Created ${trucks.length} initial trucks');
    }

    final routes = <RouteModel>[];
    final cities = <City>[];

    return GameState(
      player: player,
      factories: factories,
      warehouses: warehouses,
      trucks: trucks,
      routes: routes,
      cities: cities,
      purchasedBuildings: purchasedBuildings,
    );
  }

  /// Başlangıç trucklarını oluştur - oyuncunun ilk truck filosu
  List<Truck> _createInitialTrucks() {
    final starterSpecs = ['small', 'medium'];
    return starterSpecs.map((specId) {
      final spec = TruckCatalog.getById(specId);
      if (spec == null) return null;
      return Truck(
        id: 'truck_${spec.id}_${DateTime.now().millisecondsSinceEpoch}',
        name: spec.name,
        typeId: spec.id,
        level: 1,
        baseCapacity: spec.baseCapacity,
        baseSpeed: spec.baseSpeed,
        baseReliability: spec.baseReliability,
        durability: 100,
        mileage: 0,
        status: TruckStatus.idle,
      );
    }).whereType<Truck>().toList();
  }

  Future<void> deleteFactory(GameState state, String factoryId) async {
    state.removeFactory(factoryId);
    await _hive.deleteFactory(factoryId);
    notifyListeners();
  }

  Future<void> deleteWarehouse(GameState state, String warehouseId) async {
    state.removeWarehouse(warehouseId);
    await _hive.deleteWarehouse(warehouseId);
    notifyListeners();
  }

  Future<GameState> resetAll() async {
    await _hive.resetAll();
    final freshState = GameState(
      player: Player(nickname: 'Player', money: 10000000),
    );
    notifyListeners();
    return freshState;
  }

  void toggleAutoSave() {
    _autoSaveEnabled = !_autoSaveEnabled;
  }

  void setSaveInterval(int seconds) {
    _saveInterval = seconds;
  }

  void printDebugState(GameState state) {
    _hive.printHiveState();
  }
}