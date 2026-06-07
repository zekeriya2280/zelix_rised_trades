import 'package:flutter/material.dart';
import 'package:zelix_rised_trades/core/services/firestore_service.dart';

class Building {
  final String name;
  final String emoji;
  final String description;
  int cost;
  int count;

  Building({
    required this.name,
    required this.emoji,
    required this.description,
    required this.cost,
    this.count = 0,
  });
}

class BuildingShopScreen extends StatefulWidget {
  const BuildingShopScreen({super.key});

  @override
  State<BuildingShopScreen> createState() => _BuildingShopScreenState();
}

class _BuildingShopScreenState extends State<BuildingShopScreen> {
  int money = 100000;
  List<Map<String, dynamic>> purchases = [];

  final List<Building> buildings = [
    Building(
      name: 'Forest',
      emoji: '🌲',
      description: 'Produces 5 Wood every 30s',
      cost: 5000,
    ),
    Building(
      name: 'Field',
      emoji: '🌾',
      description: 'Produces crops over time',
      cost: 8000,
    ),
    Building(
      name: 'Lumber Mill',
      emoji: '🪚',
      description: 'Converts 10 Wood → 5 Lumber',
      cost: 15000,
    ),
    Building(
      name: 'Furniture Factory',
      emoji: '🪑',
      description: 'Converts 10 Lumber → 2 Furniture',
      cost: 30000,
    ),
    Building(
      name: 'Warehouse',
      emoji: '🏭',
      description: 'Increases storage capacity',
      cost: 50000,
    ),
  ];
  @override
  initState() {
    super.initState();
    loadPurchases();
  }

  Future<void> loadPurchases() async {
    await FirestoreService().getAllPurchases().then((data) {
      setState(() {
        purchases = data;
      });
    });
    if (purchases.isEmpty) {
      print('No purchases found in Firestore.');
      return;
    }
    for (final purchase in purchases) {
      final buildingName = purchase['building'];
      final cost = purchase['cost'];
      final count = purchase['count'];
      //final building = buildings.firstWhere((b) => b.name == buildingName, orElse: () => Building(name: buildingName, emoji: '❓', description: 'Unknown building', cost: cost));
      for (final building in buildings) {
        if (building.name == buildingName) {
          setState(() {
            building.count = count;
            building.cost = cost;
          });
          break;
        }
      }
    }
  }

  Future<void> buyBuilding(int index) async {
    final building = buildings[index];
    if (money < building.cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Not enough money for ${building.name}!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      money -= building.cost;
      building.count++;
      building.cost = (building.cost * 1.3).round();
    });
    await FirestoreService().updatePurchasedBuildings(building);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${building.emoji} ${building.name} purchased!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (purchases.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.amber[100],
          title: Container(
            alignment: Alignment.center,
            child: const Text(
              'Building Shop',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.brown,
                fontSize: 22,
                letterSpacing: 1.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
        body: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.brown[700]!, Colors.brown[500]!],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.brown.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.monetization_on,
                    color: Colors.amber,
                    size: 32,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '¥ $money',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 250),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.brown),
                  strokeWidth: 4,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Building Shop',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.brown,
            fontSize: 22,
            letterSpacing: 1.5,
            fontStyle: FontStyle.italic,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.amber[100],
      ),
      backgroundColor: Color(0xFFF5E6CA),
      body: Column(
        children: [
          // Money card at top
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.brown[700]!, Colors.brown[500]!],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.brown.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.monetization_on,
                  color: Colors.amber,
                  size: 32,
                ),
                const SizedBox(width: 8),
                Text(
                  '¥ $money',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Select a building to purchase:',
              style: TextStyle(
                fontSize: 16,
                color: Colors.brown[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

          // Building list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: buildings.length,
              itemBuilder: (context, index) {
                final building = buildings[index];
                final canAfford = money >= building.cost;

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: canAfford ? Colors.green[300]! : Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => buyBuilding(index),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Emoji
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: canAfford
                                  ? Colors.green[50]
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                building.emoji,
                                style: const TextStyle(fontSize: 36),
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      building.name,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.brown[800],
                                      ),
                                    ),
                                    if (building.count > 0) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.brown[100],
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          'x${building.count}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.brown[600],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  building.description,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Price and buy button
                          Column(
                            children: [
                              Text(
                                '¥${building.cost}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: canAfford
                                      ? Colors.green[700]
                                      : Colors.red[400],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: canAfford
                                      ? Colors.green[600]
                                      : Colors.grey[400],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'BUY',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Owned buildings summary at bottom
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.brown[50],
              border: Border(top: BorderSide(color: Colors.brown[200]!)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Buildings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown[700],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: buildings
                      .where((b) => b.count > 0)
                      .map(
                        (b) => Text(
                          '${b.emoji} ${b.name}: ${b.count}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.brown[600],
                          ),
                        ),
                      )
                      .toList(),
                ),
                if (buildings.every((b) => b.count == 0))
                  Text(
                    'No buildings yet. Buy one above!',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[500],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
