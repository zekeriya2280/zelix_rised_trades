import 'package:flutter/material.dart';
import 'package:zelix_rised_trades/screens/building_shop_screen.dart';
import 'package:zelix_rised_trades/screens/factory_screen.dart';
import '../core/enums/resource_type.dart';
import '../core/models/warehouse.dart';
import '../core/services/hive_service.dart';

class WarehouseScreen extends StatefulWidget {
  final String warehouseId;

  const WarehouseScreen({super.key, required this.warehouseId});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  final HiveService _hive = HiveService();

  Warehouse? _warehouse;

  @override
  void initState() {
    super.initState();
    _loadWarehouse();
  }

  void _loadWarehouse() {
    setState(() {
      _warehouse = _hive.getWarehouse(widget.warehouseId);
    });
  }

  String _getResourceEmoji(ResourceType type) {
    switch (type) {
      case ResourceType.wood:
        return '🌲';
      case ResourceType.lumber:
        return '🪚';
      case ResourceType.furniture:
        return '🪑';
    }
  }

  Color _getResourceColor(ResourceType type) {
    switch (type) {
      case ResourceType.wood:
        return Colors.green;
      case ResourceType.lumber:
        return Colors.brown;
      case ResourceType.furniture:
        return Colors.orange;
    }
  }

  Widget _resourceCard(ResourceType type, int amount, int capacity) {
    final color = _getResourceColor(type);
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _getResourceEmoji(type),
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.name[0].toUpperCase() + type.name.substring(1),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: capacity > 0 ? amount / capacity : 0,
                    minHeight: 6,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$amount',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: type == ResourceType.wood
                      ? Colors.green[700]
                      : (type == ResourceType.lumber
                            ? Colors.brown[700]
                            : Colors.orange[700]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logCard(WarehouseLog log) {
    IconData icon;
    Color iconColor;

    switch (log.operation) {
      case 'in':
        icon = Icons.arrow_downward;
        iconColor = Colors.green;
        break;
      case 'out':
        icon = Icons.arrow_upward;
        iconColor = Colors.red;
        break;
      default:
        icon = Icons.info_outline;
        iconColor = Colors.blue;
    }

    final time =
        '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          log.reason,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Row(
          children: [
            if (log.type != null) ...[
              Text(
                '${_getResourceEmoji(log.type!)} ${log.type!.name}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              if (log.amount > 0) ...[
                const SizedBox(width: 4),
                Text(
                  log.operation == 'in' ? '+${log.amount}' : '-${log.amount}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: log.operation == 'in'
                        ? Colors.green[600]
                        : Colors.red[400],
                  ),
                ),
              ],
              const SizedBox(width: 8),
            ],
            Text(time, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
        dense: true,
      ),
    );
  }

  Widget _buildContent(Warehouse warehouse) {
    final usedCapacity = warehouse.stock.values.fold(
      0,
      (sum, value) => sum + value,
    );
    final capacityPercent = warehouse.capacity == 0
        ? 0.0
        : usedCapacity / warehouse.capacity;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Capacity card
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.inventory,
                          color: Colors.teal,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Storage Capacity',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: capacityPercent,
                    minHeight: 16,
                    backgroundColor: Colors.teal[100],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Free: ${warehouse.freeCapacity}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '$usedCapacity / ${warehouse.capacity}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Resources section
          const Text(
            'Resources',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          ...ResourceType.values.map((resource) {
            return _resourceCard(
              resource,
              warehouse.get(resource),
              warehouse.capacity,
            );
          }),

          const SizedBox(height: 24),

          // Logs section
          const Text(
            'Recent Activity',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (warehouse.logs.isEmpty)
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                child: const Center(
                  child: Text(
                    'No activity yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            )
          else
            ...warehouse.logs.take(20).map((log) => _logCard(log)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.factory, color: Colors.black54),
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) =>
                    FactoryScreen(warehouseId: widget.warehouseId),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart, color: Colors.black54),
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => BuildingShopScreen()),
            ),
          ),
        ],
        title: Center(
          child: Text(
            _warehouse?.name ?? 'Warehouse',
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 30,
              letterSpacing: 1.5,
              fontStyle: FontStyle.italic,
              shadows: [
                Shadow(
                  offset: Offset(2, 2),
                  blurRadius: 3,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
      body: _warehouse == null
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(_warehouse!),
    );
  }
}