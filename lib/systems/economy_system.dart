import '../core/world.dart';

class EconomySystem {
  bool buyProduct(
    World world,

    String warehouseId,

    String productId,

    int amount,
  ) {
    final product = world.products[productId];

    final warehouse = world.warehouses[warehouseId];

    if (product == null || warehouse == null) {
      return false;
    }

    final total = getBuyPrice(world, productId) * amount;

    if (world.money < total) {
      return false;
    }

    if (!warehouse.addProduct(productId, amount)) {
      return false;
    }

    world.money -= total;

    return true;
  }

  bool sellProduct(
    World world,

    String warehouseId,

    String productId,

    int amount,
  ) {
    final warehouse = world.warehouses[warehouseId];

    if (warehouse == null) {
      return false;
    }

    if (!warehouse.removeProduct(productId, amount)) {
      return false;
    }

    world.money += getSellPrice(world, productId) * amount;

    return true;
  }

  void update(World world, Duration delta) {
    updateInflation(world);
  }

  void updateInflation(World world) {
    if (world.money > 1000000) {
      world.inflation += 0.00001;
    }
  }

  int getBuyPrice(World world, String productId) {
    final product = world.products[productId];

    if (product == null) {
      return 0;
    }

    return (product.basePurchasePrice * (1 + world.inflation)).round();
  }

  int getSellPrice(World world, String productId) {
    final product = world.products[productId];

    if (product == null) {
      return 0;
    }

    return (product.baseSalePrice * (1 + world.inflation)).round();
  }
}
