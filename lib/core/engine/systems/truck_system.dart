import 'package:flutter/foundation.dart';

import '../../database/truck_db.dart';
import '../../enums/resource_type.dart';
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

  @override
  void init(GameState state) {
    debugPrint('[TruckSystem] Initialized - ${state.trucks.length} trucks');
  }

  @override
  void update(GameState state) {
    _processPendingShipments(state);
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
      assignedRouteId: null,
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
    required String toWarehouseId,
    required ResourceType resourceType,
    required int amount,
    required String routeId,
    String reason = 'transport',
  }) {
    if (fromWarehouseId == toWarehouseId) {
      debugPrint('[TruckSystem] Shipment rejected: from and to must be different');
      return;
    }
    final hasDepot = (state.purchasedBuildings['Truck Depot'] ?? 0) > 0;
    if (!hasDepot) {
      debugPrint('[TruckSystem] Shipment rejected: Truck Depot is not owned');
      return;
    }

    _pendingShipments.add(_Shipment(
      fromWarehouseId: fromWarehouseId,
      toWarehouseId: toWarehouseId,
      resourceType: resourceType,
      amount: amount,
      routeId: routeId,
      reason: reason,
    ));
    debugPrint('[TruckSystem] Shipment queued: $amount ${resourceType.name}');
  }

  void _processPendingShipments(GameState state) {
    if (_pendingShipments.isEmpty) return;

    final shipmentsToProcess = List<_Shipment>.from(_pendingShipments);
    _pendingShipments.clear();

    for (final shipment in shipmentsToProcess) {
      _executeShipment(state, shipment);
    }
  }

  bool _executeShipment(GameState state, _Shipment shipment) {
    final from = state.getWarehouse(shipment.fromWarehouseId);
    final to = state.getWarehouse(shipment.toWarehouseId);

    if (from == null || to == null) {
      debugPrint('[TruckSystem] Shipment failed: warehouse not found');
      return false;
    }

    // assignedRouteId üzerinden truckları bul (Item 19)
    final trucksOnRoute = getTrucksByRoute(state, shipment.routeId);
    if (trucksOnRoute.isEmpty) {
      debugPrint('[TruckSystem] Shipment failed: no truck on route ${shipment.routeId}');
      return false;
    }

    // İlk uygun truck
    final truck = trucksOnRoute.first;

    // Yeni getter'ları kullan (Item 3-5, 14)
    final effectiveCapacity = truck.effectiveCapacity;
    final effectiveAmount = shipment.amount.clamp(1, effectiveCapacity);

    if (!to.canAdd(effectiveAmount)) {
      debugPrint('[TruckSystem] Shipment failed: target full');
      return false;
    }

    // Arıza olasılığı - failureChance kullan (Item 20)
    final rnd = DateTime.now().microsecondsSinceEpoch % 100000;
    final p = (rnd % 1000) / 1000.0;
    if (p < truck.failureChance) {
      // Arıza varsa truck'ı broken yap (Item 20)
      breakTruck(state, truck.id);
      debugPrint('[TruckSystem] Truck ${truck.id} fault! shipment cancelled');
      return false;
    }

    final removed = from.remove(
      shipment.resourceType,
      effectiveAmount,
      reason: '${shipment.reason} (out)',
    );
    if (!removed) return false;

    to.add(
      shipment.resourceType,
      effectiveAmount,
      reason: '${shipment.reason} (in)',
    );

    // Sevkiyat sonrası truck durumunu güncelle
    moveTruck(state, truck.id, shipment.toWarehouseId);

    notifyListeners();
    debugPrint('[TruckSystem] Shipment completed: truck=${truck.id}, level=${truck.level}, amount=$effectiveAmount');
    return true;
  }

  List<Truck> getAllTrucks(GameState state) {
    return List.from(state.trucks);
  }

  @override
  void dispose() {
    _pendingShipments.clear();
    super.dispose();
  }
}

class _Shipment {
  final String fromWarehouseId;
  final String toWarehouseId;
  final String routeId;
  final ResourceType resourceType;
  final int amount;
  final String reason;

  _Shipment({
    required this.fromWarehouseId,
    required this.toWarehouseId,
    required this.routeId,
    required this.resourceType,
    required this.amount,
    required this.reason,
  });

  @override
  String toString() {
    return '$amount ${resourceType.name} $fromWarehouseId -> $toWarehouseId (route=$routeId)';
  }
}