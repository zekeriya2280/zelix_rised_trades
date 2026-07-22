import 'package:zelix_rised_trades/core/engine.dart';
import 'package:zelix_rised_trades/core/game_initializer.dart';
import 'package:zelix_rised_trades/core/game_loop.dart';
import 'package:zelix_rised_trades/core/world.dart';
import 'package:zelix_rised_trades/command/command_handler.dart';
import 'package:zelix_rised_trades/systems/city_system.dart';
import 'package:zelix_rised_trades/systems/economy_system.dart';
import 'package:zelix_rised_trades/systems/factory_system.dart';
import 'package:zelix_rised_trades/systems/product_system.dart';
import 'package:zelix_rised_trades/systems/truck_system.dart';
import 'package:zelix_rised_trades/systems/warehouse_system.dart';

import '../repositories/firebase_repository.dart';

class GameService {
  World? world;

  World? get currentWorld => world;

  Engine? engine;

  GameLoop? gameLoop;

  final GameInitializer initializer;

  final FirebaseRepository firebaseRepository;

  GameService({required this.initializer, required this.firebaseRepository});

  // =========================
  // START GAME
  // =========================

  Future<void> startGame(String playerId) async {
    // 1 Firebase kontrol

    final savedWorld = await firebaseRepository.loadWorld(playerId);

    if (savedWorld != null) {
      world = savedWorld;
    } else {
      world = initializer.createNewWorld(playerId);

      await firebaseRepository.saveWorld(world!);
    }

    final factorySystem = FactorySystem();

    final warehouseSystem = WarehouseSystem();

    final truckSystem = TruckSystem();

    final economySystem = EconomySystem();

    final citySystem = CitySystem();

    final productSystem = ProductSystem();

    engine = Engine(
      world: world!,

      commandHandler: CommandHandler(
        factorySystem: factorySystem,

        truckSystem: truckSystem,

        economySystem: economySystem,
      ),

      factorySystem: factorySystem,

      warehouseSystem: warehouseSystem,

      truckSystem: truckSystem,

      economySystem: economySystem,

      citySystem: citySystem,

      productSystem: productSystem,
    );

    gameLoop = GameLoop(engine: engine!);

    gameLoop!.start();
  }

  // =========================
  // SAVE
  // =========================

  Future<void> save() async {
    if (world == null) {
      return;
    }

    await firebaseRepository.saveWorld(world!);
  }

  // =========================
  // STOP
  // =========================

  Future<void> stop() async {
    await save();

    gameLoop?.stop();
  }
}
