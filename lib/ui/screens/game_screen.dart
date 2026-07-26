import 'package:flutter/material.dart';
import 'package:zelix_rised_trades/ui/providers/game_provider.dart';
import 'package:zelix_rised_trades/ui/screens/city_screen.dart';
import 'package:zelix_rised_trades/ui/screens/market_screen.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key, required this.provider});

  final GameProvider provider;

  @override
  Widget build(BuildContext context) {
    final world = provider.world;

    if (world == null) {
      debugPrint("World is null, showing loading");
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

            // CITY & MARKET BUTTONS
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
