import 'package:flutter/foundation.dart';

import '../../services/game_service.dart';
import '../../core/world.dart';

class GameProvider extends ChangeNotifier {
  final GameService gameService;

  GameProvider({required this.gameService});

  World? get world => gameService.currentWorld;
  Future<void> initialize() async {
    await gameService.startGame("player_001");

    notifyListeners();
  }

  void refresh() {
    notifyListeners();
  }

  Future<void> buyProduct(String productId, int amount) async {
    // EconomySystem üzerinden yapılacak

    refresh();
  }

  Future<void> sellProduct(String productId, int amount) async {
    final world = this.world;

    if (world == null) {
      return;
    }

    final warehouseId = world.warehouses.keys.first;

    final success = gameService.engine!.economySystem.sellProduct(
      world,

      warehouseId,

      productId,

      amount,
    );

    if (success) {
      notifyListeners();

      await gameService.save();
    }
  }
}
