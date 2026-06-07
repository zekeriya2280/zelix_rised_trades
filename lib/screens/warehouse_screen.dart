import 'package:flutter/material.dart';
import '../core/enums/resource_type.dart';
import '../core/models/warehouse.dart';

class WarehouseScreen extends StatelessWidget {
  final Warehouse warehouse;

  const WarehouseScreen({
    super.key,
    required this.warehouse,
  });

  Widget stockTile(
    String title,
    int amount,
  ) {
    return Card(
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: Text(
          amount.toString(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Widget logTile(
    WarehouseLog log,
  ) {
    IconData icon;

    switch (log.operation) {
      case 'in':
        icon = Icons.arrow_downward;
        break;

      case 'out':
        icon = Icons.arrow_upward;
        break;

      default:
        icon = Icons.info_outline;
    }

    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(log.reason),
        subtitle: Text(log.toString()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usedCapacity =
        warehouse.stock.values.fold(
      0,
      (sum, value) => sum + value,
    );

    final capacityPercent =
        warehouse.capacity == 0
            ? 0.0
            : usedCapacity /
                warehouse.capacity;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          warehouse.name,
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            // Capacity

            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(16),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    const Text(
                      'Storage Capacity',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    LinearProgressIndicator(
                      value: capacityPercent,
                    ),

                    const SizedBox(height: 8),

                    Text(
                      '$usedCapacity / ${warehouse.capacity}',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Resources

            const Text(
              'Resources',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            ...ResourceType.values.map(
              (resource) {
                return stockTile(
                  resource.name,
                  warehouse.get(resource),
                );
              },
            ),

            const SizedBox(height: 20),

            // Logs

            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            if (warehouse.logs.isEmpty)
              const Card(
                child: Padding(
                  padding:
                      EdgeInsets.all(16),
                  child: Text(
                    'No activity yet.',
                  ),
                ),
              ),

            ...warehouse.logs
                .take(20)
                .map(
                  (log) =>
                      logTile(log),
                ),
          ],
        ),
      ),
    );
  }
}