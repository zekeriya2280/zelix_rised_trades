import 'package:flutter/material.dart';

import '../providers/game_provider.dart';

class MarketScreen extends StatelessWidget {
  final GameProvider provider;

  const MarketScreen({super.key, required this.provider});

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

    final products = warehouse.products;

    return Scaffold(
      appBar: AppBar(title: const Text("Market")),

      body: products.isEmpty
          ? const Center(child: Text("No products to sell"))
          : ListView.builder(
              itemCount: products.length,

              itemBuilder: (context, index) {
                final item = products.entries.elementAt(index);

                final productId = item.key;

                final amount = item.value;

                final product = world.products[productId];

                return Card(
                  margin: const EdgeInsets.all(8),

                  child: ListTile(
                    leading: const Icon(Icons.store),

                    title: Text(product?.name ?? productId),

                    subtitle: Text("Stock: $amount"),

                    trailing: ElevatedButton(
                      child: const Text("Sell"),

                      onPressed: () {
                        provider.sellProduct(productId, amount);
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
