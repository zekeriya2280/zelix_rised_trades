import '../enums/resource_type.dart';

class City {
  final String id;

  final String name;

  final Map<ResourceType, int> demand;

  City({
    required this.id,
    required this.name,
    required this.demand,
  });
}