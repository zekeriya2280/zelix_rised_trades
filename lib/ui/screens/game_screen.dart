import 'package:flutter/material.dart';

import '../providers/game_provider.dart';

import 'city_screen.dart';
import 'market_screen.dart';

class GameScreen extends StatelessWidget {
  final GameProvider provider;

  const GameScreen({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final world = provider.world;

    if (world == null) {
      print("haittaaaaaaaaaaaaa");
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Zelix Rised Trades")),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // MONEY
            Card(
              child: ListTile(
                leading: const Icon(Icons.attach_money),

                title: const Text("Money"),

                subtitle: Text("¥${world.money}"),
              ),
            ),

            const SizedBox(height: 10),

            // LEVEL
            Card(
              child: ListTile(
                leading: const Icon(Icons.star),

                title: const Text("Level"),

                subtitle: Text("${world.level}"),
              ),
            ),

            const SizedBox(height: 10),

            // WAREHOUSE
            Card(
              child: ListTile(
                leading: const Icon(Icons.inventory),

                title: const Text("Warehouses"),

                subtitle: Text("${world.warehouses.length}"),
              ),
            ),

            const SizedBox(height: 10),

            // FACTORIES
            Card(
              child: ListTile(
                leading: const Icon(Icons.factory),

                title: const Text("Factories"),

                subtitle: Text("${world.factories.length}"),
              ),
            ),

            const Spacer(),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    child: const Text("City"),

                    onPressed: () {
                      Navigator.push(
                        context,

                        MaterialPageRoute(
                          builder: (_) => CityScreen(provider: provider),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: ElevatedButton(
                    child: const Text("Market"),

                    onPressed: () {
                      Navigator.push(
                        context,

                        MaterialPageRoute(
                          builder: (_) => MarketScreen(provider: provider),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
