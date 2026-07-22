import 'package:flutter/material.dart';

import '../providers/game_provider.dart';

class WarehouseScreen extends StatelessWidget {
  final GameProvider provider;

  const WarehouseScreen({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final world = provider.world;

    if (world == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (world.warehouses.isEmpty) {
      return const Scaffold(body: Center(child: Text("No warehouse")));
    }

    final warehouse = world.warehouses.values.first;

    return Scaffold(
      appBar: AppBar(title: Text(warehouse.name)),

      body: Column(
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.storage),

              title: const Text("Capacity"),

              subtitle: Text(
                "${warehouse.currentCapacity} / ${warehouse.capacity}",
              ),
            ),
          ),

          Expanded(
            child: warehouse.products.isEmpty
                ? const Center(child: Text("Warehouse empty"))
                : ListView.builder(
                    itemCount: warehouse.products.length,

                    itemBuilder: (context, index) {
                      final item = warehouse.products.entries.elementAt(index);

                      final product = world.products[item.key];

                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.inventory_2),

                          title: Text(product?.name ?? item.key),

                          trailing: Text("${item.value}"),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
