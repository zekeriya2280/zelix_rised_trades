import 'package:zelix_rised_trades/core/models/truck_spec.dart';

/// TruckCatalog - Satın alınabilir truck tiplerinin kataloğu.
/// Bu katalog oyuncunun sahip olduğu truck listesinden ayrıdır.
/// Oyuncu bu katalogdaki tiplerden truck satın alabilir.
class TruckCatalog {
  static const List<TruckSpec> trucks = [
    TruckSpec(
      id: "small",
      name: "Small Truck",
      price: 50000,
      baseCapacity: 1000,
      baseSpeed: 60,
      baseReliability: 0.8,
      description: "Fast and reliable small delivery truck",
    ),
    TruckSpec(
      id: "medium",
      name: "Medium Truck",
      price: 120000,
      baseCapacity: 3000,
      baseSpeed: 50,
      baseReliability: 0.7,
      description: "Balanced medium cargo truck",
    ),
    TruckSpec(
      id: "large",
      name: "Large Truck",
      price: 250000,
      baseCapacity: 5000,
      baseSpeed: 40,
      baseReliability: 0.6,
      description: "Heavy hauler with massive capacity",
    ),
  ];

  /// ID'ye göre truck spec bul
  static TruckSpec? getById(String id) {
    try {
      return trucks.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}