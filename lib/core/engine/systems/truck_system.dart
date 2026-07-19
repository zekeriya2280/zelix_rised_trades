import 'package:flutter/foundation.dart';

import '../../database/truck_db.dart';
import '../../enums/resource_type.dart';
import '../../enums/city_list.dart';
import '../../models/truck.dart';
import '../game_state.dart';
import 'i_system.dart';

/// Kamyon yönetim sistemi.
/// Kamyon CRUD, rota atama, kaynak taşıma.
class TruckSystem extends ChangeNotifier implements ISystem {
  @override
  String get name => 'TruckSystem';

  /// Bekleyen sevkiyatlar (tick başına işlenir)
  final List<_Shipment> _pendingShipments = [];
  
  /// Aktif transportlar (status geçişleri için)
  final Map<String, _ActiveTransport> _activeTransports = {};

  @override
  void init(GameState state) {
    debugPrint('[TruckSystem] Initialized - ${state.trucks.length} trucks');
  }

  @override
  void update(GameState state) {
    _processPendingShipments(state);
    _updateActiveTransports(state);
  }

  // ==================== Truck CRUD (Items 16-23) ====================

  /// Yeni truck oluştur (Item 16 - yeni constructor)
  Truck? createTruck(
    GameState state, {
    required String id,
    required String typeId,
    int level = 1,
  }) {
    final spec = TruckCatalog.getById(typeId);
    if (spec == null) {
      debugPrint('[TruckSystem] TruckSpec not found: $typeId');
      return null;
    }

    final truck = Truck(
      id: id,
      name: spec.name,
      typeId: spec.id,
      level: level,
      baseCapacity: spec.baseCapacity,
      baseSpeed: spec.baseSpeed,
      baseReliability: spec.baseReliability,
      durability: 100,
      mileage: 0,
      status: TruckStatus.idle,
    );

    state.addTruck(truck);
    notifyListeners();
    debugPrint('[TruckSystem] Created truck: $id (type: $typeId)');
    return truck;
  }

  /// Rota ata (Item 17 - copyWith + status)
  void assignRoute(GameState state, String truckId, String routeId) {
    final index = state.trucks.indexWhere((t) => t.id == truckId);
    if (index == -1) {
      debugPrint('[TruckSystem] Truck not found: $truckId');
      return;
    }

    final updatedTruck = state.trucks[index].copyWith(
      assignedRouteId: routeId,
      status: TruckStatus.loading,
    );
    state.trucks[index] = updatedTruck;
    notifyListeners();
    debugPrint('[TruckSystem] Truck $truckId assigned to route $routeId');
  }

  /// Rotayı kaldır (Item 18 - copyWith null + idle)
  void unassignRoute(GameState state, String truckId) {
    final index = state.trucks.indexWhere((t) => t.id == truckId);
    if (index == -1) return;

    final updatedTruck = state.trucks[index].copyWith(
      assignedRouteId: null, // explicit null clears the field via sentinel
      status: TruckStatus.idle,
    );
    state.trucks[index] = updatedTruck;
    notifyListeners();
    debugPrint('[TruckSystem] Truck $truckId unassigned from route');
  }

  /// Truck hareketi / sevkiyat (Item 19 - copyWith status + warehouse)
  /// Her sevkiyatta mileage +1, durability -2 (aşınma)
  void moveTruck(GameState state, String truckId, String warehouseId) {
    final index = state.trucks.indexWhere((t) => t.id == truckId);
    if (index == -1) return;

    final current = state.trucks[index];
    final newDurability = (current.durability - 2).clamp(0, 100);
    final updatedTruck = current.copyWith(
      currentWarehouseId: warehouseId,
      status: TruckStatus.moving,
      mileage: current.mileage + 1,
      durability: newDurability,
    );
    state.trucks[index] = updatedTruck;
    notifyListeners();
  }

  /// Arıza oluştur (Item 20 - copyWith broken)
  void breakTruck(GameState state, String truckId) {
    final index = state.trucks.indexWhere((t) => t.id == truckId);
    if (index == -1) return;

    final updatedTruck = state.trucks[index].copyWith(
      status: TruckStatus.broken,
    );
    state.trucks[index] = updatedTruck;
    notifyListeners();
    debugPrint('[TruckSystem] Truck $truckId is broken!');
  }

  /// Truck tamir et (Item 21 - repair)
  void repairTruck(GameState state, String truckId) {
    final index = state.trucks.indexWhere((t) => t.id == truckId);
    if (index == -1) return;

    final updatedTruck = state.trucks[index].copyWith(
      durability: 100,
      status: TruckStatus.maintenance,
    );
    state.trucks[index] = updatedTruck;
    notifyListeners();
    debugPrint('[TruckSystem] Truck $truckId repaired');
  }

  /// Truck yükselt (Item 22 - upgrade)
  void upgradeTruck(GameState state, String truckId) {
    final index = state.trucks.indexWhere((t) => t.id == truckId);
    if (index == -1) return;

    final current = state.trucks[index];
    final updatedTruck = current.copyWith(
      level: current.level + 1,
    );
    state.trucks[index] = updatedTruck;
    notifyListeners();
    debugPrint('[TruckSystem] Truck $truckId upgraded to level ${current.level + 1}');
  }

  /// Truck sat (Item 23 - sell)
  void sellTruck(GameState state, String truckId) {
    final before = state.trucks.length;
    state.trucks.removeWhere((t) => t.id == truckId);
    if (state.trucks.length < before) {
      notifyListeners();
      debugPrint('[TruckSystem] Truck $truckId sold');
    }
  }

  // ==================== Rotadaki Trucklar ====================

  List<Truck> getTrucksByRoute(GameState state, String routeId) {
    return state.trucks.where((t) => t.assignedRouteId == routeId).toList();
  }

  List<Truck> getAvailableTrucks(GameState state) {
    return state.trucks.where((t) => t.status == TruckStatus.idle).toList();
  }

  // ==================== Sevkiyat (Shipment) ====================

  void requestShipment(
    GameState state, {
    required String fromWarehouseId,
    required CityList destinationCity,
    required ResourceType resourceType,
    required int amount,
    required String routeId,
    String reason = 'transport',
  }) {
    final warehouse = state.getWarehouse(fromWarehouseId);
    if (warehouse == null) {
      debugPrint('[TruckSystem] Shipment rejected: Warehouse not found');
      return;
    }

    // Depodaki aktif kamyon sayısı kontrolü
    final activeTrucksCount = state.trucks.where((t) =>
        t.currentWarehouseId == fromWarehouseId &&
        (t.status == TruckStatus.loading ||
            t.status == TruckStatus.moving ||
            t.status == TruckStatus.unloading)).length;

    if (activeTrucksCount >= warehouse.truckCapacity) {
      debugPrint('[TruckSystem] Shipment rejected: Warehouse truck capacity limit reached (${warehouse.truckCapacity})');
      return;
    }

    final hasDepot = (state.purchasedBuildings['Truck Depot'] ?? 0) > 0;
    if (!hasDepot) {
      debugPrint('[TruckSystem] Shipment rejected: Truck Depot is not owned');
      return;
    }

    _pendingShipments.add(_Shipment(
      fromWarehouseId: fromWarehouseId,
      destinationCity: destinationCity,
      resourceType: resourceType,
      amount: amount,
      routeId: routeId,
      reason: reason,
    ));
    debugPrint('[TruckSystem] Shipment queued: $amount ${resourceType.name} from $fromWarehouseId to ${destinationCity.name}');
  }

  void _processPendingShipments(GameState state) {
    if (_pendingShipments.isEmpty) return;

    final shipmentsToProcess = List<_Shipment>.from(_pendingShipments);
    _pendingShipments.clear();

    for (final shipment in shipmentsToProcess) {
      _startShipment(state, shipment);
    }
  }

  /// Sevkiyatı başlat - loading durumuna geçir
  void _startShipment(GameState state, _Shipment shipment) {
    final from = state.getWarehouse(shipment.fromWarehouseId);

    if (from == null) {
      debugPrint('[TruckSystem] Shipment failed: warehouse not found');
      return;
    }

    // assignedRouteId üzerinden truckları bul
    final trucksOnRoute = getTrucksByRoute(state, shipment.routeId);
    if (trucksOnRoute.isEmpty) {
      debugPrint('[TruckSystem] Shipment failed: no truck on route ${shipment.routeId}');
      return;
    }

    // İlk uygun truck
    final truck = trucksOnRoute.first;

    // Kapasite kontrolü
    final effectiveCapacity = truck.effectiveCapacity;
    final effectiveAmount = shipment.amount.clamp(1, effectiveCapacity);

    // Kaynağı depoda rezerve et (hemen düş)
    final removed = from.remove(
      shipment.resourceType,
      effectiveAmount,
      reason: '${shipment.reason} (loading)',
    );
    if (!removed) {
      debugPrint('[TruckSystem] Shipment failed: not enough resources');
      return;
    }

    // Aktif transport oluştur
    _activeTransports[truck.id] = _ActiveTransport(
      truckId: truck.id,
      shipment: shipment,
      effectiveAmount: effectiveAmount,
      ticksInLoading: 0,
      ticksInMoving: 0,
      ticksInUnloading: 0,
    );

    // Truck statusunu loading'e al
    final index = state.trucks.indexWhere((t) => t.id == truck.id);
    if (index != -1) {
      state.trucks[index] = state.trucks[index].copyWith(
        status: TruckStatus.loading,
      );
    }

    notifyListeners();
    debugPrint('[TruckSystem] Shipment started: truck=${truck.id}, amount=$effectiveAmount');
  }

  /// Aktif transportları güncelle (loading → moving → unloading → idle)
  void _updateActiveTransports(GameState state) {
    if (_activeTransports.isEmpty) return;

    final completedTrucks = <String>[];

    for (final entry in _activeTransports.entries) {
      final truckId = entry.key;
      final transport = entry.value;
      
      final truckIndex = state.trucks.indexWhere((t) => t.id == truckId);
      if (truckIndex == -1) {
        completedTrucks.add(truckId);
        continue;
      }

      final truck = state.trucks[truckIndex];

      // Loading aşaması (2 tick)
      if (transport.ticksInLoading < 2) {
        transport.ticksInLoading++;
        continue;
      }

      // Moving aşamasına geç (3 tick)
      if (transport.ticksInMoving < 3) {
        if (transport.ticksInMoving == 0) {
          // İlk kez moving'e geçiş
          // Arıza kontrolü
          final rnd = DateTime.now().microsecondsSinceEpoch % 100000;
          final p = (rnd % 1000) / 1000.0;
          if (p < truck.failureChance) {
            // Arıza varsa truck'ı broken yap
            breakTruck(state, truck.id);
            completedTrucks.add(truckId);
            debugPrint('[TruckSystem] Truck ${truck.id} fault! shipment cancelled');
            continue;
          }

          state.trucks[truckIndex] = truck.copyWith(
            status: TruckStatus.moving,
            mileage: truck.mileage + 1,
            durability: (truck.durability - 1).clamp(0, 100),
          );
          notifyListeners();
        }
        transport.ticksInMoving++;
        continue;
      }

      // Unloading aşamasına geç (2 tick)
      if (transport.ticksInUnloading < 2) {
        if (transport.ticksInUnloading == 0) {
          state.trucks[truckIndex] = truck.copyWith(
            status: TruckStatus.unloading,
          );
          notifyListeners();
        }
        transport.ticksInUnloading++;
        continue;
      }

      // Tamamlandı - teslimat ve ödeme
      _completeShipment(state, truck, transport);
      completedTrucks.add(truckId);
    }

    // Tamamlananları temizle
    for (final truckId in completedTrucks) {
      _activeTransports.remove(truckId);
    }
  }

  /// Sevkiyatı tamamla - ödeme al ve idle'a dön
  void _completeShipment(GameState state, Truck truck, _ActiveTransport transport) {
    // Şehre teslimat: gelir kazan
    int pricePerUnit = 40; // wood default
    if (transport.shipment.resourceType == ResourceType.lumber) {
      pricePerUnit = 100;
    } else if (transport.shipment.resourceType == ResourceType.furniture) {
      pricePerUnit = 350;
    }

    final revenue = transport.effectiveAmount * pricePerUnit;
    state.addMoney(revenue);

    // Şehirdeki talebi azalt (eğer varsa)
    final cityId = transport.shipment.destinationCity.name;
    try {
      final city = state.cities.firstWhere((c) => c.id == cityId || c.name == cityId);
      final currentDemand = city.demand[transport.shipment.resourceType] ?? 0;
      if (currentDemand > 0) {
        city.demand[transport.shipment.resourceType] = 
            (currentDemand - transport.effectiveAmount).clamp(0, 999999);
      }
    } catch (_) {
      // Şehir listede yoksa geç
    }

    // Truck'ı idle'a çevir
    final index = state.trucks.indexWhere((t) => t.id == truck.id);
    if (index != -1) {
      state.trucks[index] = truck.copyWith(
        status: TruckStatus.idle,
        assignedRouteId: null,
        currentWarehouseId: transport.shipment.fromWarehouseId,
        durability: (truck.durability - 1).clamp(0, 100),
      );
    }

    notifyListeners();
    debugPrint('[TruckSystem] Shipment completed: truck=${truck.id}, '
        'amount=${transport.effectiveAmount}, earned=¥$revenue');
  }

  // ==================== Diğer İşlevler ====================

  List<Truck> getAllTrucks(GameState state) {
    return List.from(state.trucks);
  }

  @override
  void dispose() {
    _pendingShipments.clear();
    _activeTransports.clear();
    super.dispose();
  }
}

// ==================== Private Sınıflar ====================

class _Shipment {
  final String fromWarehouseId;
  final CityList destinationCity;
  final String routeId;
  final ResourceType resourceType;
  final int amount;
  final String reason;

  _Shipment({
    required this.fromWarehouseId,
    required this.destinationCity,
    required this.routeId,
    required this.resourceType,
    required this.amount,
    required this.reason,
  });

  @override
  String toString() {
    return '$amount ${resourceType.name} $fromWarehouseId -> ${destinationCity.name} (route=$routeId)';
  }
}

/// Aktif transport tracking sınıfı
class _ActiveTransport {
  final String truckId;
  final _Shipment shipment;
  final int effectiveAmount;
  int ticksInLoading;
  int ticksInMoving;
  int ticksInUnloading;

  _ActiveTransport({
    required this.truckId,
    required this.shipment,
    required this.effectiveAmount,
    this.ticksInLoading = 0,
    this.ticksInMoving = 0,
    this.ticksInUnloading = 0,
  });
}