import '../enums/resource_type.dart';

class WarehouseLog {
  final ResourceType? type;
  final int amount;
  final String operation; // 'in', 'out', or 'info'
  final String reason;
  final DateTime timestamp;

  WarehouseLog({
    this.type,
    required this.amount,
    required this.operation,
    required this.reason,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type?.name,
      'amount': amount,
      'operation': operation,
      'reason': reason,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory WarehouseLog.fromMap(Map<String, dynamic> map) {
    return WarehouseLog(
      type: map['type'] != null
          ? ResourceType.values.firstWhere((e) => e.name == map['type'])
          : null,
      amount: map['amount'] as int,
      operation: map['operation'] as String,
      reason: map['reason'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  @override
  String toString() {
    final time =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    final typeLabel = type != null ? ' ${type!.name}' : '';
    final amountLabel = amount > 0 ? ': $amount' : '';
    return '[$operation]$typeLabel$amountLabel ($reason) - $time';
  }
}

class Warehouse {
  final String id;

  String name;

  int capacity;

  final String type; // 'Kaizen' | 'ChuuJou' | 'Koutou'
  final int truckCapacity;

  final Map<ResourceType, int> stock;

  final List<WarehouseLog> logs;

  Warehouse({
    required this.id,
    required this.name,
    required this.capacity,
    required this.stock,
    this.type = 'Kaizen',
    this.truckCapacity = 1,
    List<WarehouseLog>? logs,
  }) : logs = logs ?? [];

  int get(ResourceType type) {
    return stock[type] ?? 0;
  }

  int get usedCapacity {
    return stock.values.fold(0, (sum, amount) => sum + amount);
  }

  int get freeCapacity {
    return capacity - usedCapacity;
  }
  bool canAdd(int amount) {
  return freeCapacity >= amount;
}

  void add(
    ResourceType type,
    int amount, {
    required String reason,
    bool log = true,
  }) {
    if (!canAdd(amount)) {
      this.log(
      "Warehouse Full",
      type: type,
    );
      return;
    }

    stock[type] = get(type) + amount;
    if (log) {
      _addLog(type, amount, 'in', reason);
    }
  }

  bool remove(
    ResourceType type,
    int amount, {
    required String reason,
    bool log = true,
  }) {
    if (get(type) < amount) {
      return false;
    }

    stock[type] = get(type) - amount;
    if (log) {
      _addLog(type, amount, 'out', reason);
    }

    return true;
  }

  void log(String reason, {ResourceType? type}) {
    final log = WarehouseLog(
      type: type,
      amount: 0,
      operation: 'info',
      reason: reason,
      timestamp: DateTime.now(),
    );
    logs.insert(0, log);

    if (logs.length > 100) {
      logs.removeLast();
    }
  }

  void _addLog(ResourceType type, int amount, String operation, String reason) {
    final log = WarehouseLog(
      type: type,
      amount: amount,
      operation: operation,
      reason: reason,
      timestamp: DateTime.now(),
    );
    logs.insert(0, log);

    if (logs.length > 100) {
      logs.removeLast();
    }
  }

  List<WarehouseLog> getLogs({ResourceType? filterType, int limit = 50}) {
    var result = logs;
    if (filterType != null) {
      result = result.where((l) => l.type == filterType).toList();
    }
    return result.take(limit).toList();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'capacity': capacity,
      'type': type,
      'truckCapacity': truckCapacity,
      'stock': stock.map((key, value) => MapEntry(key.name, value)),
      'logs': logs.map((log) => log.toMap()).toList(),
    };
  }

  factory Warehouse.fromMap(Map<String, dynamic> map) {
    final stockMap = <ResourceType, int>{};
    if (map['stock'] != null) {
      (map['stock'] as Map<String, dynamic>).forEach((key, value) {
        stockMap[ResourceType.values.firstWhere((e) => e.name == key)] =
            value as int;
      });
    }

    List<WarehouseLog> logs = [];
    if (map['logs'] != null) {
      logs = (map['logs'] as List<dynamic>)
          .map((e) => WarehouseLog.fromMap(e as Map<String, dynamic>))
          .toList();
    }

    return Warehouse(
      id: map['id'] as String,
      name: map['name'] as String,
      capacity: map['capacity'] as int,
      type: map['type'] as String? ?? 'Kaizen',
      truckCapacity: map['truckCapacity'] as int? ?? 1,
      stock: stockMap,
      logs: logs,
    );
  }
}
