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
  }) {
    final truck = Truck(
      id: id,
      routeId: routeId,
      capacity: capacity,
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
    String reason = 'transport',
  }) {
    _pendingShipments.add(_Shipment(
      fromWarehouseId: fromWarehouseId,
      toWarehouseId: toWarehouseId,
      resourceType: resourceType,
      amount: amount,
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

    if (!to.canAdd(shipment.amount)) {
      debugPrint('[TruckSystem] Shipment failed: target full');
      return false;
    }

    final removed = from.remove(
      shipment.resourceType,
      shipment.amount,
      reason: '${shipment.reason} (out)',
    );
    if (!removed) return false;

    to.add(
      shipment.resourceType,
      shipment.amount,
      reason: '${shipment.reason} (in)',
    );

    notifyListeners();
    debugPrint('[TruckSystem] Shipment completed: $shipment');
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
  final ResourceType resourceType;
  final int amount;
  final String reason;

  _Shipment({
    required this.fromWarehouseId,
    required this.toWarehouseId,
    required this.resourceType,
    required this.amount,
    required this.reason,
  });

  @override
  String toString() {
    return '$amount ${resourceType.name} $fromWarehouseId -> $toWarehouseId';
  }
}