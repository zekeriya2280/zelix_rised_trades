import 'package:flutter/foundation.dart';

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

  Truck? createTruck(
    GameState state, {
    required String id,
    required String routeId,
    int capacity = 100,
    int level = 1,
  }) {
    final truck = Truck(
      id: id,
      routeId: routeId,
      capacity: capacity,
      level: level,
    );


    state.addTruck(truck);
    notifyListeners();
    debugPrint('[TruckSystem] Created truck: $id (route: $routeId)');
    return truck;
  }

  void assignRoute(GameState state, String truckId, String routeId) {
    final truck = state.trucks.firstWhere(
      (t) => t.id == truckId,
      orElse: () => Truck(id: '', routeId: '', capacity: 0),
    );
    if (truck.id.isEmpty) return;

    truck.routeId = routeId;
    notifyListeners();
    debugPrint('[TruckSystem] Truck $truckId assigned to route $routeId');
  }

  List<Truck> getTrucksByRoute(GameState state, String routeId) {
    return state.trucks.where((t) => t.routeId == routeId).toList();
  }

  void requestShipment(
    GameState state, {
    required String fromWarehouseId,
    required String toWarehouseId,
    required ResourceType resourceType,
    required int amount,
    required String routeId,
    String reason = 'transport',
  }) {
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

    // Truck level/capacity kuralını engine'a bağla.
    final trucksOnRoute = getTrucksByRoute(state, shipment.routeId);
    if (trucksOnRoute.isEmpty) {
      debugPrint('[TruckSystem] Shipment failed: no truck on route ${shipment.routeId}');
      return false;
    }

    // Basit: ilk uygun truck.
    final truck = trucksOnRoute.first;

    final effectiveCapacity = truck.effectiveCapacity.floor();
    final effectiveAmount = shipment.amount.clamp(1, effectiveCapacity);

    if (!to.canAdd(effectiveAmount)) {
      debugPrint('[TruckSystem] Shipment failed: target full');
      return false;
    }

    // Arıza olasılığı: seyahat başı.
    final rnd = DateTime.now().microsecondsSinceEpoch % 100000;
    final p = (rnd % 1000) / 1000.0; // 0..1
    if (p < truck.faultChance) {
      // Arıza: bekleme mantığı henüz progres sistemine bağlanmadığı için bu tick'te taşımayı yapma.
      debugPrint(
          '[TruckSystem] Truck ${truck.id} fault! duration=${truck.faultDurationSeconds}s (shipment cancelled for now)');
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

    notifyListeners();
    debugPrint('[TruckSystem] Shipment completed: $shipment (truck=${truck.id}, level=${truck.level}, amount=$effectiveAmount)');
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