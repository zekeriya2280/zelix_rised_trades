import '../core/world.dart';
import '../models/truck.dart';

class TruckSystem {
  void update(World world, Duration delta) {
    for (final truck in world.trucks.values) {
      if (truck.isMoving) {
        checkArrival(truck);
      }
    }
  }

  bool moveTruck(
    World world,

    String truckId,

    String destination,

    Duration duration,
  ) {
    final truck = world.trucks[truckId];

    if (truck == null) {
      return false;
    }

    truck.startRoute(destination: destination, duration: duration);

    return true;
  }

  void checkArrival(Truck truck) {
    if (truck.arrivalTime == null) {
      return;
    }

    if (DateTime.now().isAfter(truck.arrivalTime!)) {
      truck.arrive();
    }
  }

  bool loadTruck(World world, String truckId, String productId, int amount) {
    final truck = world.trucks[truckId];

    if (truck == null) {
      return false;
    }

    return truck.addCargo(productId, amount);
  }

  bool unloadTruck(World world, String truckId) {
    final truck = world.trucks[truckId];

    if (truck == null) {
      return false;
    }

    truck.cargo.clear();

    return true;
  }
}
