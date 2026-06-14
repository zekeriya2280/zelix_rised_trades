import 'package:flutter/foundation.dart';

import '../../enums/factory_type.dart';
import '../game_state.dart';
import 'factory_system.dart';
import 'i_system.dart';
import 'player_system.dart';
import 'warehouse_system.dart';


/// Building shop işlemlerini game-engine üzerinden yöneten sistem.
/// UI bu sisteme sadece API çağrısı yapar; satın alma kararı/maliyet/persist
/// tamamen burada çalışır.
class BuildingShopSystem extends ChangeNotifier implements ISystem {
  @override
  String get name => 'BuildingShopSystem';

  @override
  void init(GameState state) {
    debugPrint('[BuildingShopSystem] Initialized');
  }

  @override
  void update(GameState state) {
    // shop işlemleri event-driven (UI action)
  }

  // NOTE: Maliyet artışı kuralı burada tutuluyor (mevcut GameEngine.getBuildingCost ile aynı).
  int getBuildingCost({
    required String buildingName,
    required int baseCost,
    required int currentCount,
  }) {
    if (currentCount == 0) return baseCost;
    double cost = baseCost.toDouble();
    for (int i = 0; i < currentCount; i++) {
      cost *= 1.3;
    }
    return cost.round();
  }


  int getBuildingCount(GameState state, String buildingName) {
    return state.purchasedBuildings[buildingName] ?? 0;
  }

  /// Satın al.
  /// - Para düşme: state.deductMoney (player system mantığıyla uyumlu)
  /// - Factory: FactorySystem.buyFactory
  /// - Warehouse: WarehouseSystem.ensureWarehouseExists
  /// - Depot: Şimdilik satın alım sayacı tut.
  Future<bool> buyBuilding(
    GameState state, {
    required String buildingName,
    required String type, // 'factory' | 'warehouse' | 'depot'
    required int baseCost,
    required FactoryType? factoryType,
    required int warehouseCapacity,
    required PlayerSystem playerSystem,
    required FactorySystem factorySystem,
    required WarehouseSystem warehouseSystem,
  }) async {

    final currentCount = getBuildingCount(state, buildingName);
    final cost = getBuildingCost(
      buildingName: buildingName,
      baseCost: baseCost,
      currentCount: currentCount,
    );

    if (!playerSystem.canAfford(state, cost)) return false;

    // Depot/factory/warehouse hepsi purchasedBuildings sayacını artıracak.
    // Para düşme sadece satın alma akışına dahil edilir.
    final deducted = playerSystem.deductMoney(state, cost);
    if (!deducted) return false;

    if (type == 'warehouse') {
      warehouseSystem.ensureWarehouseExists(
        state,
        id: 'w${DateTime.now().millisecondsSinceEpoch}',
        name: 'Warehouse #${currentCount + 1}',
        capacity: warehouseCapacity,
      );
    } else if (type == 'factory') {
      if (factoryType == null) return false;
      final factory = factorySystem.buyFactory(state, factoryType);
      if (factory == null) return false;
    } else {
      // 'depot' => Gameplay etkisi yok; sadece sayac/başka sayfalarda gösterim.
    }


    state.purchasedBuildings[buildingName] = currentCount + 1;
    notifyListeners();
    return true;
  }

}


