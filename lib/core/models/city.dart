import '../enums/resource_type.dart';

class City {
  final String id;

  final String name;

  final Map<ResourceType, int> demand;

  /// City "distance" level (1..10). Used by TruckScreen fee/speed.
  ///
  /// This is UI/gameplay parameter (not geographic distance).
  final int distanceLevel;

  City({
    required this.id,
    required this.name,
    required this.demand,
    this.distanceLevel = 1,
  });
}

