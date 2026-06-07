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

  @override
  String toString() {
    final time = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    final typeLabel = type != null ? ' ${type!.name}' : '';
    final amountLabel = amount > 0 ? ': $amount' : '';
    return '[$operation]$typeLabel$amountLabel ($reason) - $time';
  }
}

class Warehouse {
  final String id;

  String name;

  int capacity;

  final Map<ResourceType, int> stock;

  final List<WarehouseLog> logs;

  Warehouse({
    required this.id,
    required this.name,
    required this.capacity,
    required this.stock,
    List<WarehouseLog>? logs,
  }) : logs = logs ?? [];

  int get(ResourceType type) {
    return stock[type] ?? 0;
  }

  void add(
    ResourceType type,
    int amount, {
    required String reason,
    bool log = true,
  }) {
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

  void _addLog(
    ResourceType type,
    int amount,
    String operation,
    String reason,
  ) {
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

  List<WarehouseLog> getLogs({
    ResourceType? filterType,
    int limit = 50,
  }) {
    var result = logs;
    if (filterType != null) {
      result = result.where((l) => l.type == filterType).toList();
    }
    return result.take(limit).toList();
  }
}