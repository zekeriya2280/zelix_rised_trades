enum TruckStatus { idle, loading, moving, unloading, broken, maintenance }

/// Sentinel object used in copyWith to distinguish "not provided" from null.
const _unset = Object();

class Truck {
  final String id;
  final String name;
  final String typeId;

  final int level;
  final int baseCapacity;
  final double baseSpeed;
  final double baseReliability;

  final int durability; // 0-100
  final int mileage;    // toplam kullanım
  final TruckStatus status;

  final String? assignedRouteId;
  final String? currentWarehouseId;

  const Truck({
    required this.id,
    required this.name,
    required this.typeId,
    required this.level,
    required this.baseCapacity,
    required this.baseSpeed,
    required this.baseReliability,
    required this.durability,
    required this.mileage,
    required this.status,
    this.assignedRouteId,
    this.currentWarehouseId,
  });

  Truck copyWith({
    String? id,
    String? name,
    String? typeId,
    int? level,
    int? baseCapacity,
    double? baseSpeed,
    double? baseReliability,
    int? durability,
    int? mileage,
    TruckStatus? status,
    // Use the _unset sentinel to keep the current value, or pass null explicitly
    // to clear these fields.
    Object? assignedRouteId = _unset,
    Object? currentWarehouseId = _unset,
  }) {
    return Truck(
      id: id ?? this.id,
      name: name ?? this.name,
      typeId: typeId ?? this.typeId,
      level: level ?? this.level,
      baseCapacity: baseCapacity ?? this.baseCapacity,
      baseSpeed: baseSpeed ?? this.baseSpeed,
      baseReliability: baseReliability ?? this.baseReliability,
      durability: durability ?? this.durability,
      mileage: mileage ?? this.mileage,
      status: status ?? this.status,
      assignedRouteId: identical(assignedRouteId, _unset)
          ? this.assignedRouteId
          : assignedRouteId as String?,
      currentWarehouseId: identical(currentWarehouseId, _unset)
          ? this.currentWarehouseId
          : currentWarehouseId as String?,
    );
  }

  int get effectiveCapacity => (baseCapacity * (1 + 0.2 * (level - 1))).round();

  double get effectiveSpeed => baseSpeed * (1 + 0.15 * (level - 1));

  double get failureChance {
    final wearPenalty = (100 - durability) / 200.0;
    final levelBonus = 0.12 / level;
    return (levelBonus + wearPenalty).clamp(0.0, 1.0);
  }

  // ==================== Serialization ====================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'typeId': typeId,
      'level': level,
      'baseCapacity': baseCapacity,
      'baseSpeed': baseSpeed,
      'baseReliability': baseReliability,
      'durability': durability,
      'mileage': mileage,
      'status': status.name,
      'assignedRouteId': assignedRouteId,
      'currentWarehouseId': currentWarehouseId,
    };
  }

  factory Truck.fromJson(Map<String, dynamic> json) {
    return Truck(
      id: json['id'] as String,
      name: json['name'] as String,
      typeId: json['typeId'] as String,
      level: json['level'] as int,
      baseCapacity: json['baseCapacity'] as int,
      baseSpeed: (json['baseSpeed'] as num).toDouble(),
      baseReliability: (json['baseReliability'] as num).toDouble(),
      durability: json['durability'] as int,
      mileage: json['mileage'] as int,
      status: TruckStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => TruckStatus.idle,
      ),
      assignedRouteId: json['assignedRouteId'] as String?,
      currentWarehouseId: json['currentWarehouseId'] as String?,
    );
  }
}
