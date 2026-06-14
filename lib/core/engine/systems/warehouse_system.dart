import 'package:flutter/foundation.dart';

import '../../enums/resource_type.dart';
import '../../models/warehouse.dart';
import '../game_state.dart';
import 'i_system.dart';

/// Warehouse yönetim sistemi.
/// Warehouse CRUD, kapasite yönetimi, kaynak transferi.
class WarehouseSystem extends ChangeNotifier implements ISystem {
  @override
  String get name => 'WarehouseSystem';

  @override
  void init(GameState state) {
    debugPrint('[WarehouseSystem] Initialized - ${state.warehouses.length} warehouses');
  }

  @override
  void update(GameState state) {
    // Warehouse'lar event-driven çalışır, tick gerekmez
  }

  /// Yeni warehouse oluştur
  Warehouse? createWarehouse(
    GameState state, {
    required String id,
    required String name,
    required int capacity,
    Map<ResourceType, int>? initialStock,
  }) {
    if (state.getWarehouse(id) != null) {
      debugPrint('[WarehouseSystem] Warehouse $id already exists');
      return null;
    }

    final warehouse = Warehouse(
      id: id,
      name: name,
      capacity: capacity,
      stock: initialStock ?? {
        ResourceType.wood: 0,
        ResourceType.lumber: 0,
        ResourceType.furniture: 0,
      },
    );

    state.addWarehouse(warehouse);
    notifyListeners();
    debugPrint('[WarehouseSystem] Created: $id ($name) - capacity: $capacity');
    return warehouse;
  }

  /// Warehouse varsa getir, yoksa varsayılan ile oluştur
  Warehouse ensureWarehouseExists(
    GameState state, {
    required String id,
    required String name,
    required int capacity,
  }) {
    var warehouse = state.getWarehouse(id);
    warehouse ??= createWarehouse(
        state,
        id: id,
        name: name,
        capacity: capacity,
      );
    return warehouse!;
  }

  /// Belirtilen warehouse'a kaynak ekle
  bool addResource(
    GameState state,
    String warehouseId,
    ResourceType type,
    int amount, {
    String reason = 'manual',
  }) {
    final warehouse = state.getWarehouse(warehouseId);
    if (warehouse == null) return false;

    warehouse.add(type, amount, reason: reason);
    notifyListeners();
    return true;
  }

  /// Belirtilen warehouse'dan kaynak çıkar
  bool removeResource(
    GameState state,
    String warehouseId,
    ResourceType type,
    int amount, {
    String reason = 'manual',
  }) {
    final warehouse = state.getWarehouse(warehouseId);
    if (warehouse == null) return false;

    final result = warehouse.remove(type, amount, reason: reason);
    if (result) notifyListeners();
    return result;
  }

  /// İki warehouse arasında kaynak transferi
  bool transferResource(
    GameState state,
    String fromWarehouseId,
    String toWarehouseId,
    ResourceType type,
    int amount, {
    String reason = 'transfer',
  }) {
    final from = state.getWarehouse(fromWarehouseId);
    final to = state.getWarehouse(toWarehouseId);
    if (from == null || to == null) return false;

    if (!to.canAdd(amount)) {
      debugPrint('[WarehouseSystem] Transfer failed: target warehouse full');
      return false;
    }

    final removed = from.remove(type, amount, reason: reason);
    if (!removed) return false;

    to.add(type, amount, reason: reason);
    notifyListeners();
    debugPrint('[WarehouseSystem] Transfer: $amount ${type.name} $fromWarehouseId -> $toWarehouseId');
    return true;
  }

  /// Warehouse kapasitesini artır
  void upgradeCapacity(GameState state, String warehouseId, int additionalCapacity) {
    final warehouse = state.getWarehouse(warehouseId);
    if (warehouse == null) return;

    warehouse.capacity += additionalCapacity;
    notifyListeners();
    debugPrint('[WarehouseSystem] Upgraded $warehouseId: +$additionalCapacity capacity');
  }

  /// Tüm warehouse'ları getir
  List<Warehouse> getAllWarehouses(GameState state) {
    return List.from(state.warehouses);
  }

}