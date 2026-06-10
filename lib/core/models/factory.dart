import 'package:zelix_rised_trades/core/models/warehouse.dart';

import '../enums/factory_type.dart';

class Factory {
  final String id;

  final FactoryType type;

  bool active;

  double efficiency;
  DateTime lastProduction;

  /// Tracks when upkeep was last deducted for this factory.
  /// Initialized equal to [lastProduction] so first upkeep triggers after
  /// the production cycle completes.
  DateTime lastUpkeepPaid;

  Factory({
    required this.id,
    required this.type,
    this.active = true,
    this.efficiency = 1,
    required this.lastProduction,
    DateTime? lastUpkeepPaid,
  }) : lastUpkeepPaid = lastUpkeepPaid ?? lastProduction;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString(),
      'active': active,
      'efficiency': efficiency,
      'lastProduction': lastProduction.toIso8601String(),
      'lastUpkeepPaid': lastUpkeepPaid.toIso8601String(),
    };
  }

  factory Factory.fromMap(Map<String, dynamic> map) {
    return Factory(
      id: map['id'],
      type: FactoryType.values.firstWhere((e) => e.toString() == map['type']),
      active: map['active'],
      efficiency: map['efficiency'],
      lastProduction: DateTime.parse(map['lastProduction']),
      lastUpkeepPaid: map['lastUpkeepPaid'] != null
          ? DateTime.parse(map['lastUpkeepPaid'])
          : DateTime.parse(map['lastProduction']),
    );
  }
  void update(Warehouse warehouse) {
    if (!active) return;
    final elapsed = DateTime.now().difference(lastProduction).inSeconds;

    if (elapsed < type.productionSeconds) {
      return;
    }
    if (type.input != null) {
      if (warehouse.get(type.input!) < type.inputAmount) {
        return;
      }

      warehouse.remove(
        type.input!,
        type.inputAmount,
        reason: "$type production",
      );
    }

    warehouse.add(type.output, type.outputAmount, reason: "$type production");

    lastProduction = DateTime.now();
  }
}
