// 107. Adım
//
// WarehouseSystem gerçek stok yönetimi
//
// Amaç:
// - Depo kapasitesi kontrolü
// - Ürün giriş/çıkış yönetimi
// - FactorySystem ve EconomySystem ile ortak stok mantığı
// - Multiplayer için güvenli stok değişim noktası
//
// Akış:
//
// FactorySystem
//       ↓
// WarehouseSystem
//       ↓
// Warehouse
//       ↓
// World
//
// Tek bir state kaynağı kullanmak ve iş mantığını katmanlara ayırmak,
// büyük uygulamalarda veri tutarlılığı için önerilen yaklaşımlardandır.
// :contentReference[oaicite:0]{index=0}

// lib/systems/warehouse_system.dart

import '../core/world.dart';
import '../models/warehouse.dart';

class WarehouseSystem {
  void update(World world, Duration delta) {
    // Gelecekte:
    //
    // - depo genişletme
    // - bozulma
    // - bakım maliyeti
    // - lojistik yoğunluğu
    //
  }

  // =========================
  // ADD PRODUCT
  // =========================

  bool addProduct(
    World world,

    String warehouseId,

    String productId,

    int amount,
  ) {
    final warehouse = world.warehouses[warehouseId];

    if (warehouse == null) {
      return false;
    }

    return warehouse.addProduct(productId, amount);
  }

  // =========================
  // REMOVE PRODUCT
  // =========================

  bool removeProduct(
    World world,

    String warehouseId,

    String productId,

    int amount,
  ) {
    final warehouse = world.warehouses[warehouseId];

    if (warehouse == null) {
      return false;
    }

    return warehouse.removeProduct(productId, amount);
  }

  // =========================
  // CHECK STOCK
  // =========================

  bool hasProduct(
    World world,

    String warehouseId,

    String productId,

    int amount,
  ) {
    final warehouse = world.warehouses[warehouseId];

    if (warehouse == null) {
      return false;
    }

    return warehouse.getProduct(productId) >= amount;
  }

  // =========================
  // CAPACITY
  // =========================

  int getFreeCapacity(World world, String warehouseId) {
    final warehouse = world.warehouses[warehouseId];

    if (warehouse == null) {
      return 0;
    }

    return warehouse.capacity - warehouse.currentCapacity;
  }

  // =========================
  // CREATE WAREHOUSE
  // =========================

  void createWarehouse(World world, Warehouse warehouse) {
    world.warehouses[warehouse.id] = warehouse;
  }

  // =========================
  // DELETE WAREHOUSE
  // =========================

  bool removeWarehouse(World world, String warehouseId) {
    if (!world.warehouses.containsKey(warehouseId)) {
      return false;
    }

    world.warehouses.remove(warehouseId);

    return true;
  }
}
