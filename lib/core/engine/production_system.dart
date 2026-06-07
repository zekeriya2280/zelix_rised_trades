import '../constants/recipes.dart';
import '../enums/factory_type.dart';
import '../models/factory.dart';
import '../models/warehouse.dart';

class ProductionSystem {
  final Warehouse warehouse;

  final List<Factory> factories;

  ProductionSystem({
    required this.warehouse,
    required this.factories,
  });

  void tick() {
    for (final factory in factories) {
      switch (factory.type) {
        case FactoryType.lumberMill:

          if (warehouse.remove(
            lumberRecipe.input,
            lumberRecipe.inputAmount,
            reason: 'Lumber mill production input',
          )) {
            warehouse.add(
              lumberRecipe.output,
              lumberRecipe.outputAmount,
              reason: 'Lumber mill production output',
            );
          }

          break;

        case FactoryType.furnitureFactory:

          if (warehouse.remove(
            furnitureRecipe.input,
            furnitureRecipe.inputAmount,
            reason: 'Furniture factory production input',
          )) {
            warehouse.add(
              furnitureRecipe.output,
              furnitureRecipe.outputAmount,
              reason: 'Furniture factory production output',
            );
          }

          break;
      }
    }
  }
}