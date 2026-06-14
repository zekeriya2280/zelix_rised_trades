class Truck {
  final String id;

  String routeId;

  /// Base capacity (level'e göre efektif kapasite artar)
  int capacity;

  /// Level arttıkça capacity ve speed artar, arıza ihtimali azalır.
  int level;

  Truck({
    required this.id,
    required this.routeId,
    required this.capacity,
    this.level = 1,
  });

  /// Senin tarifine göre ~1.2x (level başına) artış yaklaşımı.
  double get effectiveCapacity => capacity * (1.0 + 0.2 * (level - 1));

  /// Senin tarifine göre ~1.3x (level başına) hızlanma yaklaşımı.
  double get effectiveSpeedMultiplier => 1.0 + 0.3 * (level - 1);

  /// Arıza olasılığı level ile azalır.
  /// (Probability: seyahat başına rastgele)
  double get faultChance => (0.12 / level).clamp(0.0, 1.0);

  /// Arıza süresi (bekleme) - level arttıkça azalır.
  int get faultDurationSeconds => (10.0 / level).round().clamp(1, 20);

  @override
  String toString() {
    return 'Truck{id: $id, routeId: $routeId, level: $level, capacity: $capacity}';
  }
}
