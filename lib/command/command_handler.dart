// 102. Adım
//
// Engine + Systems + CommandHandler bağlantısı
//
// Amaç:
// - CommandHandler artık gerçek sistemleri çağıracak
// - Multiplayer komutları mevcut oyun motoruna bağlanacak
// - Yeni oyun mantığı yazılmayacak
//
// Yapı:
//
// GameCommand
//      ↓
// CommandHandler
//      ↓
// Existing Systems
//      ↓
// World
//
// Command yaklaşımı, işlemleri ayrı nesneler olarak
// yöneterek uygulama mantığını ayırmaya yardımcı olur.
// ([docs.flutter.dev](https://docs.flutter.dev/app-architecture/design-patterns/command))

// lib/network/command_handler.dart

import '../core/world.dart';

import 'game_command.dart';

import '../systems/factory_system.dart';
import '../systems/truck_system.dart';
import '../systems/economy_system.dart';

class CommandHandler {
  final FactorySystem factorySystem;

  final TruckSystem truckSystem;

  final EconomySystem economySystem;

  CommandHandler({
    required this.factorySystem,

    required this.truckSystem,

    required this.economySystem,
  });

  bool handle(World world, GameCommand command) {
    switch (command.type) {
      case CommandType.buyFactory:
        return factorySystem.buyFactory(world, command.data["factoryId"]);

      case CommandType.startProduction:
        return factorySystem.startProduction(world, command.data["factoryId"]);

      case CommandType.moveTruck:
        return truckSystem.moveTruck(
          world,

          command.data["truckId"],

          command.data["destination"],

          command.data["duration"],
        );

      case CommandType.buyProduct:
        return economySystem.buyProduct(
          world,

          command.data["productId"],

          command.data["warehouseid"],

          command.data["amount"],
        );

      case CommandType.sellProduct:
        return economySystem.sellProduct(
          world,

          command.data["productId"],

          command.data["warehouseid"],

          command.data["amount"],
        );

      default:
        return false;
    }
  }
}
