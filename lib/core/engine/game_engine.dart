import 'dart:async';

import 'package:flutter/foundation.dart';

import '../database/truck_db.dart';
import '../enums/factory_type.dart';
import '../enums/resource_type.dart';
import '../enums/city_list.dart';
import '../models/factory.dart' as models;
import '../models/player.dart';
import '../models/warehouse.dart';
import '../models/truck.dart';

import 'game_state.dart';
import 'systems/city_system.dart';
import 'systems/factory_system.dart';
import 'systems/i_system.dart';
import 'systems/building_shop_system.dart';

import 'systems/player_system.dart';






import 'systems/route_system.dart';
import 'systems/save_system.dart';
import 'systems/truck_system.dart';
import 'systems/warehouse_system.dart';


/// Ana oyun motoru.
/// 
/// Tüm sistemleri yönetir, tick döngüsünü çalıştırır,
/// UI'a tek erişim noktası sağlar.
/// 
/// UI ASLA doğrudan HiveService veya sistemlere erişmez.
/// Her şey bu merkez üzerinden yapılır.
class GameEngine {
  // ---- Singleton ----
  static final GameEngine _instance = GameEngine._internal();
  factory GameEngine() => _instance;
  GameEngine._internal();

  // ---- Timer ----
  Timer? _timer;
  bool _running = false;
  bool get isRunning => _running;

  // ---- Systems ----
  late final PlayerSystem playerSystem;
  late final FactorySystem factorySystem;
  late final WarehouseSystem warehouseSystem;
  late final TruckSystem truckSystem;
  late final RouteSystem routeSystem;
  late final CitySystem citySystem;
  late final SaveSystem saveSystem;
  late final BuildingShopSystem buildingShopSystem;


  /// Tüm sistemlerin listesi (sıralı tick için)
  late final List<ISystem> _systems;

  // ---- Central Game State ----
  GameState _state = GameState(
    player: Player(nickname: 'Player', money: 10000000),
  );

  /// Mevcut state (UI tarafından okunur, asla direkt değiştirilmez)
  GameState get state => _state;

  // ---- Reactive Notifiers (UI için) ----

  /// Her tick'te tetiklenir (UI progress bar güncellemesi için)
  final ValueNotifier<int> tickNotifier = ValueNotifier<int>(0);

  /// State değiştiğinde tetiklenir (UI yeniden çizim için)
  final ValueNotifier<int> stateVersion = ValueNotifier<int>(0);

  /// Player para değişimi için
  final ValueNotifier<int> moneyNotifier = ValueNotifier<int>(10000000);

  /// Factory listesi değişimi için
  final ValueNotifier<List<models.Factory>> factoriesNotifier =
      ValueNotifier<List<models.Factory>>([]);

  /// Warehouse haritası değişimi için
  final ValueNotifier<Map<String, Warehouse>> warehousesNotifier =
      ValueNotifier<Map<String, Warehouse>>({});

  // ---- Lifecycle ----

  /// Motoru başlat
  void start() {
    if (_running) return;
    _running = true;

    debugPrint('[GameEngine] Starting...');

    // Sistemleri oluştur
    _initSystems();

    // State'i Hive'dan yükle
    _loadState();

    // Sistemleri başlat
    for (final system in _systems) {
      system.init(_state);
    }

    // UI notifier'larını güncelle
    _syncNotifiers();

    // Tick döngüsünü başlat
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tick();
    });

    debugPrint('[GameEngine] Started.');
  }

  /// Sistemleri oluştur
  void _initSystems() {
    playerSystem = PlayerSystem();
    factorySystem = FactorySystem();
    warehouseSystem = WarehouseSystem();
    truckSystem = TruckSystem();
    routeSystem = RouteSystem();
    citySystem = CitySystem();
    saveSystem = SaveSystem();
    buildingShopSystem = BuildingShopSystem();


    _systems = [
      playerSystem,
      factorySystem,
      warehouseSystem,
      buildingShopSystem,
      truckSystem,
      routeSystem,
      citySystem,
      saveSystem,
    ];


    // ChangeNotifier olan sistemleri dinle
    for (final system in _systems) {
      if (system is ChangeNotifier) {
        (system as ChangeNotifier).addListener(_onSystemChanged);
      }
    }
  }

  /// Herhangi bir sistem değiştiğinde UI'ı güncelle
  void _onSystemChanged() {
    _syncNotifiers();
  }

  /// UI notifier'larını güncelle
  void _syncNotifiers() {
    moneyNotifier.value = _state.player.money;
    factoriesNotifier.value = List.from(_state.factories);

    final warehouseMap = <String, Warehouse>{};
    for (final w in _state.warehouses) {
      warehouseMap[w.id] = w;
    }
    warehousesNotifier.value = warehouseMap;

    stateVersion.value++;
  }

  /// State'i Hive'dan yükle
  void _loadState() {
    _state = saveSystem.load();
    debugPrint('[GameEngine] State loaded: ${_state.factories.length} factories, '
        '${_state.warehouses.length} warehouses');
  }

  /// Motoru durdur
  void stop() {
    if (!_running) return;
    _running = false;

    saveSystem.save(_state);

    _timer?.cancel();
    _timer = null;

    for (final system in _systems) {
      if (system is ChangeNotifier) {
        (system as ChangeNotifier).removeListener(_onSystemChanged);
      }
    }

    debugPrint('[GameEngine] Stopped.');
  }

  /// Her saniye çalışan tick
  void _tick() {
    tickNotifier.value++;

    for (final system in _systems) {
      system.update(_state);
    }
  }

  // ==================== UI API ====================

  // ---- Player ----

  bool canAfford(int cost) => playerSystem.canAfford(_state, cost);

  /// Oyuncu parasını düş (factory/warehouse satın alımı için)
  bool deductMoney(int cost) {
    return playerSystem.deductMoney(_state, cost);
  }

  // ---- Factory ----

  /// Yeni factory satın al (para otomatik düşer)
  models.Factory? buyFactory(FactoryType type) {
    // FactorySystem maliyet hesabını yapıp satın alma akışını tamamlar
    return factorySystem.buyFactory(_state, type);
  }

  void toggleFactory(String factoryId) {
    factorySystem.toggleFactory(_state, factoryId);
    saveSystem.save(_state);
  }

  List<models.Factory> getFactories() => factorySystem.getFactories(_state);

  // ---- Warehouse ----

  Warehouse ensureWarehouseExists({
    required String id,
    required String name,
    required int capacity,
    String type = 'Kaizen',
    int truckCapacity = 1,
  }) {
    final warehouse = warehouseSystem.ensureWarehouseExists(
      _state,
      id: id,
      name: name,
      capacity: capacity,
      type: type,
      truckCapacity: truckCapacity,
    );
    saveSystem.save(_state);
    return warehouse;
  }

  bool addResourceToWarehouse(
    String warehouseId,
    ResourceType type,
    int amount, {
    String reason = 'manual',
  }) {
    final result = warehouseSystem.addResource(
      _state, warehouseId, type, amount, reason: reason,
    );
    if (result) saveSystem.save(_state);
    return result;
  }

  bool removeResourceFromWarehouse(
    String warehouseId,
    ResourceType type,
    int amount, {
    String reason = 'manual',
  }) {
    final result = warehouseSystem.removeResource(
      _state, warehouseId, type, amount, reason: reason,
    );
    if (result) saveSystem.save(_state);
    return result;
  }

  bool transferResource(
    String fromWarehouseId,
    String toWarehouseId,
    ResourceType type,
    int amount, {
    String reason = 'transfer',
  }) {
    final result = warehouseSystem.transferResource(
      _state, fromWarehouseId, toWarehouseId, type, amount, reason: reason,
    );
    if (result) saveSystem.save(_state);
    return result;
  }

  void upgradeWarehouseCapacity(String warehouseId, int additionalCapacity) {
    warehouseSystem.upgradeCapacity(_state, warehouseId, additionalCapacity);
    saveSystem.save(_state);
  }

  Warehouse? getWarehouse(String id) => _state.getWarehouse(id);

  List<Warehouse> getAllWarehouses() =>
      warehouseSystem.getAllWarehouses(_state);

  // ---- Truck ----

  /// Yeni truck oluştur (Item 16 - yeni parametreler)
  void createTruck({
    required String id,
    required String typeId,
    int level = 1,
  }) {
    truckSystem.createTruck(
      _state,
      id: id,
      typeId: typeId,
      level: level,
    );
    saveSystem.save(_state);
  }

  void assignTruckRoute(String truckId, String routeId) {
    truckSystem.assignRoute(_state, truckId, routeId);
    saveSystem.save(_state);
  }

  void unassignTruckRoute(String truckId) {
    truckSystem.unassignRoute(_state, truckId);
    saveSystem.save(_state);
  }

  void requestShipment({
    required String fromWarehouseId,
    required CityList destinationCity,
    required ResourceType resourceType,
    required int amount,
    required String routeId,
    String reason = 'transport',
  }) {
    truckSystem.requestShipment(
      _state,
      fromWarehouseId: fromWarehouseId,
      destinationCity: destinationCity,
      resourceType: resourceType,
      amount: amount,
      routeId: routeId,
      reason: reason,
    );
  }

  // ---- Truck Yeni API'lar (Items 21-23) ----

  /// Truck tamir et (Item 21)
  void repairTruck(String truckId) {
    truckSystem.repairTruck(_state, truckId);
    saveSystem.save(_state);
  }

  /// Truck yükselt (Item 22)
  void upgradeTruck(String truckId) {
    truckSystem.upgradeTruck(_state, truckId);
    saveSystem.save(_state);
  }

  /// Truck sat (Item 23)
  void sellTruck(String truckId) {
    truckSystem.sellTruck(_state, truckId);
    saveSystem.save(_state);
  }

  /// Katalogdan truck satın al (para düşer + truck oluşur)
  bool buyTruck(String typeId) {
    final spec = TruckCatalog.getById(typeId);
    if (spec == null) return false;
    if (!canAfford(spec.price)) return false;

    deductMoney(spec.price);
    final newId = 'truck_${typeId}_${DateTime.now().millisecondsSinceEpoch}';
    truckSystem.createTruck(_state, id: newId, typeId: typeId, level: 1);
    saveSystem.save(_state);
    _syncNotifiers();
    debugPrint('[GameEngine] Bought truck: $typeId for ¥${spec.price}');
    return true;
  }

  // ---- Truck UI Model / Derived Info (Item 15 - yeni getter'lar) ----

  int getTruckCapacity(String truckId) {
    final truck = _state.trucks.where((t) => t.id == truckId).cast<Truck?>().firstOrNull;
    if (truck == null) return 0;
    return truck.effectiveCapacity;
  }

  int getTruckLevel(String truckId) {
    final truck = _state.trucks.where((t) => t.id == truckId).cast<Truck?>().firstOrNull;
    return truck?.level ?? 1;
  }

  double getTruckEffectiveSpeed(String truckId) {
    final truck = _state.trucks.where((t) => t.id == truckId).cast<Truck?>().firstOrNull;
    return truck?.effectiveSpeed ?? 1.0;
  }

  double getTruckFailureChance(String truckId) {
    final truck = _state.trucks.where((t) => t.id == truckId).cast<Truck?>().firstOrNull;
    return truck?.failureChance ?? 0.0;
  }

  /// Fee: UI’da yapılan basit formül
  double calculateShipmentFee({
    required int limitedAmount,
    required int cityDistanceLevel,
  }) {
    const double unitPrice = 0.35;
    return cityDistanceLevel * limitedAmount * unitPrice;
  }


  // ---- Route ----

  void createRoute({
    required String id,
    required String source,
    required String destination,
    int trucks = 0,
  }) {
    routeSystem.createRoute(
      _state,
      id: id,
      source: source,
      destination: destination,
      trucks: trucks,
    );
    saveSystem.save(_state);
  }

  void deleteRoute(String routeId) {
    routeSystem.deleteRoute(_state, routeId);
    saveSystem.save(_state);
  }

  // ---- City ----

  void createCity({
    required String id,
    required String name,
    Map<ResourceType, int>? demand,
  }) {
    citySystem.createCity(
      _state,
      id: id,
      name: name,
      demand: demand,
    );
    saveSystem.save(_state);
  }

  // ---- Building Shop ----

  int getBuildingCount(String buildingName) {
    return buildingShopSystem.getBuildingCount(_state, buildingName);
  }

  int getBuildingCost(String buildingName, int baseCost, int currentCount) {
    return buildingShopSystem.getBuildingCost(
      buildingName: buildingName,
      baseCost: baseCost,
      currentCount: currentCount,
    );
  }

  Future<bool> buyBuilding({
    required String buildingName,
    required String type,
    required int baseCost,
    required FactoryType? factoryType,
    required int warehouseCapacity,
    String warehouseType = 'Kaizen',
    int truckCapacity = 1,
  }) {
    return buildingShopSystem.buyBuilding(
      _state,
      buildingName: buildingName,
      type: type,
      baseCost: baseCost,
      factoryType: factoryType,
      warehouseCapacity: warehouseCapacity,
      warehouseType: warehouseType,
      truckCapacity: truckCapacity,
      playerSystem: playerSystem,
      factorySystem: factorySystem,
      warehouseSystem: warehouseSystem,
    ).then((ok) {
      if (ok) {
        saveSystem.save(_state);
        _syncNotifiers();
      }
      return ok;
    });
  }

  // ---- Save / Load ----


  Future<void> saveGame() async {
    await saveSystem.save(_state);
  }

  Future<void> resetGame() async {
    _state = await saveSystem.resetAll();
    _syncNotifiers();
    debugPrint('[GameEngine] Game has been reset');
  }

  void printDebugState() {
    saveSystem.printDebugState(_state);
  }

  // ---- Cleanup ----

  void dispose() {
    stop();
    tickNotifier.dispose();

    stateVersion.dispose();
    moneyNotifier.dispose();
    factoriesNotifier.dispose();
    warehousesNotifier.dispose();

    for (final system in _systems) {
      system.dispose();
    }
  }
}