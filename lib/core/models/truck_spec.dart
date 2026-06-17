/// TruckSpec - Bir truck tipinin istatistik tanımı.
/// Örneğin "Small Truck", "Medium Truck", "Large Truck" gibi katalogdaki tipler.
/// Bu bir oyuncunun sahip olduğu truck değil, satın alınabilir truck türüdür.
class TruckSpec {
  final String id;
  final String name;
  final int price;
  final int baseCapacity;
  final double baseSpeed;
  final double baseReliability;
  final String description;

  const TruckSpec({
    required this.id,
    required this.name,
    required this.price,
    required this.baseCapacity,
    required this.baseSpeed,
    required this.baseReliability,
    this.description = '',
  });
}