import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/enums/factory_type.dart';
import '../core/enums/resource_type.dart';
import '../core/engine/production_system.dart';
import '../core/models/city.dart';
import '../core/models/factory.dart';
import '../core/models/game_state.dart';
import '../core/models/route_model.dart';
import '../core/models/truck.dart';
import '../core/models/warehouse.dart';

final gameProvider =
    NotifierProvider<GameNotifier, GameState>(
  GameNotifier.new,
);

class GameNotifier extends Notifier<GameState> {
  late ProductionSystem _productionSystem;

  @override
  GameState build() {
    final gameState = GameState(
      warehouse: Warehouse(
        id: 'main_warehouse',
        name: 'Main Warehouse',
        capacity: 100000,
        stock: {
          ResourceType.wood: 100,
          ResourceType.lumber: 0,
          ResourceType.furniture: 0,
        },
      ),
      factories: [
        Factory(
          id: 'lumber_1',
          type: FactoryType.lumberMill,
        ),
        Factory(
          id: 'furniture_1',
          type: FactoryType.furnitureFactory,
        ),
      ],
      trucks: [
        Truck(
          id: 'truck_1',
          routeId: 'route_1',
          capacity: 100,
        ),
      ],
      routes: [
        RouteModel(
          id: 'route_1',
          source: 'Warehouse',
          destination: 'City',
          trucks: 1,
        ),
      ],
      cities: [
        City(
          id: 'city_1',
          name: 'Tokyo',
          demand: {
            ResourceType.furniture: 1000,
          },
        ),
      ],
    );

    _productionSystem = ProductionSystem(
      warehouse: gameState.warehouse,
      factories: gameState.factories,
    );

    return gameState;
  }

  void tick() {
    _productionSystem.tick();

    state = GameState(
      warehouse: state.warehouse,
      factories: state.factories,
      trucks: state.trucks,
      routes: state.routes,
      cities: state.cities,
    );
  }

  void addWood(int amount) {
    state.warehouse.add(
      ResourceType.wood,
      amount,
      reason: 'Manual wood injection',
    );

    state = GameState(
      warehouse: state.warehouse,
      factories: state.factories,
      trucks: state.trucks,
      routes: state.routes,
      cities: state.cities,
    );
  }
}