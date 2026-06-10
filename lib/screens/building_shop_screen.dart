import 'package:flutter/material.dart';
import 'package:zelix_rised_trades/core/engine/game_engine.dart';
import 'package:zelix_rised_trades/core/models/building.dart';
import 'package:zelix_rised_trades/core/models/factory.dart';
import 'package:zelix_rised_trades/core/models/player.dart';
import 'package:zelix_rised_trades/core/services/firestore_service.dart';
import 'package:zelix_rised_trades/core/enums/factory_type.dart';
import 'package:zelix_rised_trades/screens/factory_screen.dart';
import 'package:zelix_rised_trades/screens/warehouse_screen.dart';

class BuildingShopScreen extends StatefulWidget {
  const BuildingShopScreen({super.key});

  @override
  State<BuildingShopScreen> createState() => _BuildingShopScreenState();
}

class _BuildingShopScreenState extends State<BuildingShopScreen> {
  int money = 100000;
  final GameEngine _engine = GameEngine();
  List<Map<String, dynamic>> purchases = [];
  bool isLoading = true;

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
    // Listen to GameEngine's real-time player money from Firebase
    _engine.playerNotifier.addListener(_onPlayerChanged);
    _loadData();
  }

  @override
  void dispose() {
    _engine.playerNotifier.removeListener(_onPlayerChanged);
    super.dispose();
  }

  void _onPlayerChanged() {
    if (!mounted) return;
    setState(() {
      money = _engine.playerNotifier.value.money;
    });
  }

  Future<void> _loadData() async {
    await _loadPurchases();
  }

  Future<void> _savePlayer() async {
    await FirestoreService().savePlayer(Player(nickname: 'Player', money: money));
  }

  Future<void> _loadPurchases() async {
    try {
      final data = await FirestoreService()
          .getAllPurchases()
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        purchases = data;
        isLoading = false;
      });

      if (purchases.isEmpty) {
        print('No purchases found in Firestore.');
        return;
      }
      for (final purchase in purchases) {
        final buildingName = purchase['building'];
        final cost = purchase['cost'];
        final count = purchase['count'];
        for (final building in buildings) {
          if (building.name == buildingName) {
            building.count = count;
            building.cost = cost;
            break;
          }
        }
        if (mounted) setState(() {});
      }
    } catch (e) {
      print('Firestore loading failed: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
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
    await _savePlayer(); // Save player money to Firestore

    // If the purchased building is a factory type, save it to the factories collection
    FactoryType? factoryType;
    switch (building.name) {
      case 'Forest':
        factoryType = FactoryType.forest;
        break;
      case 'Lumber Mill':
        factoryType = FactoryType.lumberMill;
        break;
      case 'Furniture Factory':
        factoryType = FactoryType.furnitureFactory;
        break;
    }

    if (factoryType != null) {
      final factoryId = '${factoryType.name}_${DateTime.now().millisecondsSinceEpoch}';
      final factory = Factory(
        id: factoryId,
        type: factoryType,
        active: true,
        efficiency: 1.0,
        lastProduction: DateTime.now().subtract(
          Duration(seconds: factoryType.productionSeconds),
        ), // Start ready to produce
      );
      await FirestoreService().saveFactory(factory);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${building.emoji} ${building.name} purchased!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Game'),
        content: const Text(
          'This will delete all factories and purchases, '
          'and reset the warehouse to default stock.\n\n'
          'Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirestoreService().resetAll();
      setState(() {
        money = 100000;
        for (final building in buildings) {
          building.count = 0;
        }
      });
      await _loadPurchases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Game reset to beginning!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
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
        actions: [
            IconButton(
            icon: Icon(Icons.factory, color: Colors.black54),
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => FactoryScreen(
                  warehouseId: "w1",
                ),
              ),
            ),
          ),
            IconButton(
              icon: Icon(Icons.warehouse, color: Colors.black54),
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
              builder: (context) => WarehouseScreen(warehouseId: "w1"),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.restart_alt, color: Colors.red),
              tooltip: 'Reset Game',
              onPressed: () => _confirmReset(context),
            ),
          ],
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
