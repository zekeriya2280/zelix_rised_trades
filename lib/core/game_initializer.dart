// 110. Adım
//
// GameInitializer + gerçek başlangıç dünyası
//
// Amaç:
// - Yeni oyuncu başladığında World oluşturmak
// - İlk para
// - İlk depo
// - İlk kaynak
// - İlk fabrika
// - İlk ürün zinciri
//
// Akış:
//
// App Start
//    ↓
// GameInitializer
//    ↓
// World
//    ↓
// Engine
//    ↓
// GameLoop
//
// Flutter mimarisinde başlangıç verilerini ve servis kurulumlarını
// uygulama mantığından ayırmak, katmanların sorumluluklarını net tutar.
// ([docs.flutter.dev](https://docs.flutter.dev/app-architecture/guide))

// lib/core/game_initializer.dart

import 'world.dart';

import '../models/product.dart';
import '../models/factory.dart';
import '../models/warehouse.dart';

class GameInitializer {
  World createNewWorld(String playerId) {
    final world = World(
      playerId: playerId,

      playerName: "Player",

      money: 100000,

      level: 1,

      inflation: 0,
    );

    _createProducts(world);

    _createWarehouse(world);

    _createForest(world);

    _createLumberMill(world);

    return world;
  }

  // =========================
  // PRODUCTS
  // =========================

  void _createProducts(World world) {
    world.products["wood"] = Product(
      id: "wood",

      name: "Wood",

      basePurchasePrice: 50,

      baseSalePrice: 80,

      level: 1,

      category: '',
      productionTime: 10,
    );

    world.products["lumber"] = Product(
      id: "lumber",

      name: "Lumber",

      basePurchasePrice: 150,

      baseSalePrice: 250,

      level: 1,

      requiredMaterials: {"wood": 2},

      productionTime: 10,
      category: '',
    );
  }

  // =========================
  // WAREHOUSE
  // =========================

  void _createWarehouse(World world) {
    world.warehouses["main"] = Warehouse(
      id: "main",

      name: "Main Warehouse",

      capacity: 500,
    );
  }

  // =========================
  // FOREST
  // =========================

  void _createForest(World world) {
    world.factories["forest_1"] = Factory(
      id: "forest_1",

      name: "Forest",

      outputProduct: "wood",

      type: "Forest",

      productionTime: 30,

      productionAmount: 5,
    );
  }

  // =========================
  // LUMBER MILL
  // =========================

  void _createLumberMill(World world) {
    world.factories["lumber_mill_1"] = Factory(
      id: "lumber_mill_1",

      name: "Lumber Mill",

      outputProduct: "lumber",

      type: "Forest",

      productionTime: 60,

      productionAmount: 1,

      requiredMaterials: {"wood": 2},
    );
  }
}
