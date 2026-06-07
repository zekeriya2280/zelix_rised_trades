import '../enums/factory_type.dart';

class Factory {
  final String id;

  final FactoryType type;

  bool active;

  double efficiency;

  Factory({
    required this.id,
    required this.type,
    this.active = true,
    this.efficiency = 1,
  });
}