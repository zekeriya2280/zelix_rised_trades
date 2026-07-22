import 'package:flutter/material.dart';

import '../providers/game_provider.dart';

class FactoryScreen extends StatelessWidget {
  final GameProvider provider;

  const FactoryScreen({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final world = provider.world;

    if (world == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final factories = world.factories.values.toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Factories")),

      body: factories.isEmpty
          ? const Center(child: Text("No factories"))
          : ListView.builder(
              itemCount: factories.length,

              itemBuilder: (context, index) {
                final factory = factories[index];

                final product = world.products[factory.outputProduct];

                return Card(
                  margin: const EdgeInsets.all(8),

                  child: ListTile(
                    leading: const Icon(Icons.factory),

                    title: Text(factory.name),

                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text("Level: ${factory.level}"),

                        Text(
                          "Output: ${product?.name ?? factory.outputProduct}",
                        ),

                        Text(factory.isRunning ? "Running" : "Stopped"),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
