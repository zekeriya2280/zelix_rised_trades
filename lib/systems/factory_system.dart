import '../core/world.dart';
import '../models/factory.dart';
import '../models/warehouse.dart';

class FactorySystem {
  final Map<String, Factory> catalog = {
    "lumber_mill": Factory(
      id: "lumber_mill",

      name: "Lumber Mill",

      upgradeCost: 50000,
      type: '',
      outputProduct: '',
      productionAmount: 10,
      productionTime: 10,
    ),
  };

  bool buyFactory(World world, String factoryId) {
    final factory = catalog[factoryId];

    if (factory == null) {
      return false;
    }

    if (!world.spendMoney(factory.upgradeCost)) {
      return false;
    }

    world.factories[factoryId] = factory;

    return true;
  }

  void update(World world, Duration delta) {
    for (final factory in world.factories.values) {
      if (factory.isRunning) {
        processProduction(world, factory);
      }
    }
  }

  bool startProduction(World world, String factoryId) {
    final factory = world.factories[factoryId];

    if (factory == null) {
      return false;
    }

    if (factory.isRunning) {
      return false;
    }

    factory.start();

    return true;
  }

  void processProduction(World world, Factory factory) {
    final now = DateTime.now();

    final elapsed = now.difference(factory.lastProductionTime);

    if (elapsed.inSeconds < factory.productionTime) {
      return;
    }

    final warehouse = world.warehouses[factory.locationId];

    if (warehouse == null) {
      return;
    }

    // hammadde kontrolü

    for (final material in factory.requiredMaterials.entries) {
      if (warehouse.getProduct(material.key) < material.value) {
        return;
      }
    }

    // hammadde düş

    for (final material in factory.requiredMaterials.entries) {
      warehouse.removeProduct(material.key, material.value);
    }

    // ürün ekle

    warehouse.addProduct(factory.outputProduct, factory.productionAmount);

    factory.lastProductionTime = now;
  }
}
