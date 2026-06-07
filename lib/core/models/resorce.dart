import '../enums/resource_type.dart';

class Resource {
  final ResourceType type;
  int amount;

  Resource({
    required this.type,
    required this.amount,
  });
}