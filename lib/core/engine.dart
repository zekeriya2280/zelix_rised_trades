// 105. Adım
//
// Engine içine gerçek System listesi bağlama
//
// Amaç:
// - Engine artık bütün oyun sistemlerini yönetecek
// - GameLoop tick geldiğinde tüm sistemler sırayla çalışacak
// - Factory, Warehouse, Truck, Economy, City, Product aynı merkezden güncellenecek
//
// Akış:
//
// GameLoop
//    ↓
// Engine.update()
//    ↓
// Systems.update()
//    ↓
// World
//
// Oyun motorlarında merkezi update döngüsü,
// oyun durumunun sürekli güncellenmesi için kullanılır.
// ([docs.flame-engine.org](https://docs.flame-engine.org/latest/flame/game.html)) :contentReference[oaicite:0]{index=0}
//
// Flutter mimarisinde de sorumlulukları ayırmak ve
// iş mantığını ayrı katmanlarda tutmak önerilen yaklaşımlardandır.
// :contentReference[oaicite:1]{index=1}

// lib/core/engine.dart

import 'world.dart';

import '../command/game_command.dart';
import '../command/command_handler.dart';

import '../systems/factory_system.dart';
import '../systems/warehouse_system.dart';
import '../systems/truck_system.dart';
import '../systems/economy_system.dart';
import '../systems/city_system.dart';
import '../systems/product_system.dart';

class Engine {
  final World world;

  final CommandHandler commandHandler;

  final FactorySystem factorySystem;

  final WarehouseSystem warehouseSystem;

  final TruckSystem truckSystem;

  final EconomySystem economySystem;

  final CitySystem citySystem;

  final ProductSystem productSystem;

  final List<GameCommand> _commands = [];

  Engine({
    required this.world,

    required this.commandHandler,

    required this.factorySystem,

    required this.warehouseSystem,

    required this.truckSystem,

    required this.economySystem,

    required this.citySystem,

    required this.productSystem,
  });

  // =========================
  // COMMAND QUEUE
  // =========================

  void addCommand(GameCommand command) {
    _commands.add(command);
  }

  // =========================
  // MAIN UPDATE
  // =========================

  void update(Duration delta) {
    _processCommands();

    productSystem.update(world, delta);

    citySystem.update(world, delta);

    warehouseSystem.update(world, delta);

    factorySystem.update(world, delta);

    truckSystem.update(world, delta);

    economySystem.update(world, delta);
  }

  // =========================
  // COMMAND PROCESS
  // =========================

  void _processCommands() {
    if (_commands.isEmpty) {
      return;
    }

    final commands = List<GameCommand>.from(_commands);

    _commands.clear();

    for (final command in commands) {
      commandHandler.handle(world, command);
    }
  }
}
