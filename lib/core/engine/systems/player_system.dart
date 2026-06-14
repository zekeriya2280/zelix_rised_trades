import 'package:flutter/foundation.dart';

import '../game_state.dart';
import 'i_system.dart';

/// Oyuncu yönetim sistemi.
/// Para ekleme/çıkarma, nickname değiştirme vb. işlemler.
class PlayerSystem extends ChangeNotifier implements ISystem {
  @override
  String get name => 'PlayerSystem';

  @override
  void init(GameState state) {
    debugPrint('[PlayerSystem] Initialized - Money: ¥${state.player.money}');
  }

  @override
  void update(GameState state) {
    // Player tick'i gerekmez, event-driven
  }

  /// Oyuncuya para ekle
  bool addMoney(GameState state, int amount) {
    if (amount <= 0) return false;
    state.addMoney(amount);
    notifyListeners();
    debugPrint('[PlayerSystem] +¥$amount -> ¥${state.player.money}');
    return true;
  }

  /// Oyuncudan para düş
  bool deductMoney(GameState state, int amount) {
    if (amount <= 0) return false;
    final result = state.deductMoney(amount);
    if (result) {
      notifyListeners();
      debugPrint('[PlayerSystem] -¥$amount -> ¥${state.player.money}');
    } else {
      debugPrint('[PlayerSystem] Insufficient funds: ¥${state.player.money} < ¥$amount');
    }
    return result;
  }

  /// Toplam upkeep maliyetini düş (factory tick'i için)
  bool deductUpkeep(GameState state, int totalUpkeep) {
    if (totalUpkeep <= 0) return true;
    return deductMoney(state, totalUpkeep);
  }

  /// Yeterli para var mı?
  bool canAfford(GameState state, int cost) {
    return state.player.money >= cost;
  }

}