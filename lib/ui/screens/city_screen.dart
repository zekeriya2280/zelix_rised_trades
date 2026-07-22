import 'package:flutter/material.dart';

import '../providers/game_provider.dart';

class CityScreen extends StatelessWidget {
  final GameProvider provider;

  const CityScreen({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final world = provider.world;

    if (world == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final cities = world.cities;

    return Scaffold(
      appBar: AppBar(title: const Text("Cities")),

      body: cities.isEmpty
          ? const Center(child: Text("No cities available"))
          : ListView.builder(
              itemCount: cities.length,

              itemBuilder: (context, index) {
                final city = cities.entries.elementAt(index);

                return Card(
                  margin: const EdgeInsets.all(8),

                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.location_city),
                    ),

                    title: Text(city.key),

                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text("Level: ${city.value["level"] ?? 1}"),

                        Text("Population: ${city.value["population"] ?? 0}"),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
