import 'package:flutter/foundation.dart' hide Factory;

import '../../enums/factory_type.dart';
import '../../models/factory.dart' as models;
import '../../models/warehouse.dart';
import '../game_state.dart';
import 'i_system.dart';

/// Factory yönetim sistemi.
/// Factory açma/kapama, otomatik üretim, verimlilik vb.
/// Warehouse doluysa otomatik olarak boş warehouse'a yönlendirir.
class FactorySystem extends ChangeNotifier implements ISystem {
  @override
  String get name => 'FactorySystem';

  int _totalUpkeepThisCycle = 0;
  int get totalUpkeepThisCycle => _totalUpkeepThisCycle;

  int _productionCount = 0;
  int get productionCount => _productionCount;

  @override
  void init(GameState state) {
    debugPrint('[FactorySystem] Initialized - ${state.factories.length} factories');
  }

  @override
  void update(GameState state) {
    _totalUpkeepThisCycle = 0;
    _productionCount = 0;

    for (final factory in state.factories) {
      if (!factory.active) continue;
      _processFactory(state, factory);
    }
  }

  void _processFactory(GameState state, models.Factory factory) {
    final elapsed = DateTime.now().difference(factory.lastProduction).inSeconds;
    if (elapsed < factory.type.productionSeconds) return;

    // Input için uygun warehouse bul
    final inputWarehouse = _findWarehouseForInput(state, factory);
    if (inputWarehouse == null) {
      debugPrint('[FactorySystem] No warehouse with input for ${factory.id}');
      return;
    }

    // Input yeterli mi kontrol et
    if (!_hasEnoughInput(factory, inputWarehouse)) return;

    // HESAPLA: Output miktarı
    final outputAmount = (factory.type.outputAmount * factory.efficiency).round();

    // ÖNCE KONTROL ET: Output için uygun warehouse var mı?
    // (Input tüketilmeden önce kontrol edilir, böylece input kaybolmaz)
    final targetWarehouse = _findWarehouseForOutput(state, factory, outputAmount);
    if (targetWarehouse == null) {
      debugPrint('[FactorySystem] All warehouses full! ${factory.id} waiting for space...');
      // lastProduction DEĞİŞTİRİLMEZ - slider 100%'de "Ready" kalır
      // Yeni warehouse alınınca boş yer açılır → bir sonraki tick'te üretim başlar
      return;
    }

    // Input tüket (sadece output warehouse garantiyse)
    if (factory.type.input != null) {
      inputWarehouse.remove(
        factory.type.input!,
        factory.type.inputAmount,
        reason: '${factory.type.name} production',
      );
    }

    // Output ekle
    targetWarehouse.add(
      factory.type.output,
      outputAmount,
      reason: '${factory.type.name} production',
    );

    factory.lastProduction = DateTime.now();
    _productionCount++;
    _totalUpkeepThisCycle += factory.type.upkeepCost;
    notifyListeners();
    debugPrint(
      '[FactorySystem] ${factory.type.name} produced $outputAmount ${factory.type.output.name} -> ${targetWarehouse.id}',
    );
  }

  /// Input için uygun warehouse bul (prefix eşleşmesi ile)
  Warehouse? _findWarehouseForInput(GameState state, models.Factory factory) {
    final prefix = factory.id.split('_').first;
    try {
      return state.warehouses.firstWhere((w) => w.id == prefix);
    } catch (_) {
      if (state.warehouses.isNotEmpty) {
        return state.warehouses.first;
      }
    }
    return null;
  }

  bool _hasEnoughInput(models.Factory factory, Warehouse warehouse) {
    if (factory.type.input == null) return true;
    return warehouse.get(factory.type.input!) >= factory.type.inputAmount;
  }

  /// Output için en uygun warehouse'u bul.
  /// 1. Tercih: input warehouse (eğer boş yer varsa)
  /// 2. Tercih: herhangi bir boş warehouse
  /// 3. Tercih: hiçbiri → null
  Warehouse? _findWarehouseForOutput(GameState state, models.Factory factory, int outputAmount) {
    final inputWarehouse = _findWarehouseForInput(state, factory);

    // Önce input warehouse'u dene (boş yer varsa)
    if (inputWarehouse != null && inputWarehouse.canAdd(outputAmount)) {
      return inputWarehouse;
    }

    // Input warehouse dolu → diğer tüm warehouse'ları tara
    for (final w in state.warehouses) {
      if (w != inputWarehouse && w.canAdd(outputAmount)) {
        debugPrint('[FactorySystem] Redirect ${factory.id} -> ${w.id} (was full: ${inputWarehouse?.id})');
        return w;
      }
    }

    return null; // Tüm warehouse'lar dolu
  }

  models.Factory? buyFactory(GameState state, FactoryType type) {
    final factory = models.Factory(
      id: '${type.name}_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      active: true,
      efficiency: 1.0,
      lastProduction: DateTime.now().subtract(
        Duration(seconds: type.productionSeconds),
      ),
    );

    state.addFactory(factory);
    notifyListeners();
    debugPrint('[FactorySystem] New factory: ${factory.id}');
    return factory;
  }

  void toggleFactory(GameState state, String factoryId) {
    final factory = state.getFactory(factoryId);
    if (factory == null) return;
    factory.active = !factory.active;
    notifyListeners();
    debugPrint('[FactorySystem] ${factory.id} active=${factory.active}');
  }

  List<models.Factory> getFactories(GameState state) {
    return List.from(state.factories);
  }

  @override
  void dispose() {
    super.dispose();
  }
}