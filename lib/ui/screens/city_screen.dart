import 'package:flutter/material.dart';
import 'package:zelix_rised_trades/ui/providers/game_provider.dart';

class CityScreen extends StatelessWidget {
  const CityScreen({super.key, required this.provider});

  final GameProvider provider;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff07152B),

      appBar: AppBar(
        title: const Text("Cities"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.add),
        label: const Text("New City"),
        onPressed: () {},
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),

        children: [
          // City Item 1
          Card(
            margin: const EdgeInsets.only(bottom: 16),

            child: ListTile(
              leading: const Icon(
                Icons.location_city,
                size: 48,
                color: Colors.blue,
              ),

              title: const Text("Tokyo", style: TextStyle(fontSize: 20)),

              subtitle: const Text("Production: 50/hour"),

              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            ),
          ),

          // City Item 2
          Card(
            margin: const EdgeInsets.only(bottom: 16),

            child: ListTile(
              leading: const Icon(
                Icons.location_city,
                size: 48,
                color: Colors.green,
              ),

              title: const Text("Osaka", style: TextStyle(fontSize: 20)),

              subtitle: const Text("Production: 30/hour"),

              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            ),
          ),

          // City Item 3
          Card(
            margin: const EdgeInsets.only(bottom: 16),

            child: ListTile(
              leading: const Icon(
                Icons.location_city,
                size: 48,
                color: Colors.red,
              ),

              title: const Text("Kyoto", style: TextStyle(fontSize: 20)),

              subtitle: const Text("Production: 20/hour"),

              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
