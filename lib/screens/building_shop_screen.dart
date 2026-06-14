import 'package:flutter/material.dart';
import 'package:zelix_rised_trades/core/engine/game_engine.dart';
import 'package:zelix_rised_trades/core/enums/factory_type.dart';
import 'package:zelix_rised_trades/screens/factory_screen.dart';
import 'package:zelix_rised_trades/screens/hive_screen.dart';
import 'package:zelix_rised_trades/screens/route_screen.dart';
import 'package:zelix_rised_trades/screens/truck_screen.dart';
import 'package:zelix_rised_trades/screens/warehouse_screen.dart';


/// Building Shop - Sadece GameEngine üzerinden veri okur/yazar.
/// Building count ve cost GameState'te kalıcı olarak saklanır.
/// UI rebuild'lerde veri kaybolmaz.
class BuildingShopScreen extends StatefulWidget {
  const BuildingShopScreen({super.key});

  @override
  State<BuildingShopScreen> createState() => _BuildingShopScreenState();
}

class _BuildingShopScreenState extends State<BuildingShopScreen> {
  final GameEngine _engine = GameEngine();

  static const List<_BuildingInfo> _buildings = [
    _BuildingInfo(
      name: 'Forest',
      emoji: '🌲',
      description: 'Produces 5 Wood every 30s',
      baseCost: 5000,
      type: 'factory',
    ),
    _BuildingInfo(
      name: 'Field',
      emoji: '🌾',
      description: 'Produces crops over time',
      baseCost: 8000,
      type: 'factory',
    ),
    _BuildingInfo(
      name: 'Lumber Mill',
      emoji: '🪚',
      description: 'Converts 10 Wood → 5 Lumber',
      baseCost: 15000,
      type: 'factory',
    ),
    _BuildingInfo(
      name: 'Furniture Factory',
      emoji: '🪑',
      description: 'Converts 10 Lumber → 2 Furniture',
      baseCost: 30000,
      type: 'factory',
    ),
    _BuildingInfo(
      name: 'Warehouse',
      emoji: '🏭',
      description: 'Increases storage capacity',
      baseCost: 50000,
      type: 'warehouse',
    ),
    _BuildingInfo(
      name: 'Truck Depot',
      emoji: '🚚',
      description: 'Required to start warehouse → city transport',
      baseCost: 120000,
      type: 'depot',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _engine.moneyNotifier.addListener(_onDataChanged);
    _engine.stateVersion.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _engine.moneyNotifier.removeListener(_onDataChanged);
    _engine.stateVersion.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  /// Kalıcı state'ten building count'u al
  int _getCount(String name) => _engine.getBuildingCount(name);

  Future<void> buyBuilding(int index) async {
    final building = _buildings[index];
    final count = _getCount(building.name);
    final cost = _engine.getBuildingCost(
      building.name,
      building.baseCost,
      count,
    );

    if (!_engine.canAfford(cost)) {
      _showSnack('❌ Not enough money for ${building.name}!', Colors.red);
      return;
    }

    final purchaseOk = await _engine.buyBuilding(
      buildingName: building.name,
      baseCost: building.baseCost,
      type: building.type,
      factoryType: _getFactoryType(building.name),
      warehouseCapacity: 500,
    );

    if (purchaseOk != true) {
      _showSnack('❌ Purchase failed!', Colors.red);
      return;
    }

    _showSnack('${building.emoji} ${building.name} purchased!', Colors.green);
  }

  FactoryType? _getFactoryType(String name) {
    switch (name) {
      case 'Forest':
        return FactoryType.forest;
      case 'Lumber Mill':
        return FactoryType.lumberMill;
      case 'Furniture Factory':
        return FactoryType.furnitureFactory;
      default:
        return null;
    }
  }

  void _showSnack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: bg,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Game'),
        content: const Text('This will delete all data. Are you sure?'),
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
      await _engine.resetGame();
      if (mounted) {
        _showSnack('✅ Game reset to beginning!', Colors.green);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final money = _engine.moneyNotifier.value;

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
        actions: [],
        centerTitle: true,
        backgroundColor: Colors.amber[100],
      ),
      backgroundColor: const Color(0xFFF5E6CA),
      body: Column(
        children: [
          // Money card
          Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.amber[100],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.route_outlined, color: Colors.black54),
                      tooltip: 'Routes',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const RouteScreen()),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.local_shipping, color: Colors.black54),
                      tooltip: 'Trucks',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const TruckScreen()),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.storage, color: Colors.black54),
                      tooltip: 'Hive Database',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const HiveScreen()),
                      ),
                    ),

                    IconButton(
                      icon: const Icon(Icons.factory, color: Colors.black54),
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) =>
                              const FactoryScreen(warehouseId: "w1"),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.warehouse, color: Colors.black54),
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) =>
                              const WarehouseScreen(warehouseId: "w1"),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.restart_alt, color: Colors.red),
                      tooltip: 'Reset Game',
                      onPressed: () => _confirmReset(context),
                    ),
                    //nst SizedBox(width: 8),
                    //xt('Building Shop', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.brown[800], letterSpacing: 1.2)),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
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
            ],
          ),
          const SizedBox(height: 8),
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
              itemCount: _buildings.length,
              itemBuilder: (context, index) {
                final building = _buildings[index];
                final count = _getCount(building.name);
                final cost = _engine.getBuildingCost(
                  building.name,
                  building.baseCost,
                  count,
                );
                final canAfford = money >= cost;

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
                                    if (count > 0) ...[
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
                                          'x$count',
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
                          Column(
                            children: [
                              Text(
                                '¥$cost',
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
          // Owned buildings summary (GameState'ten okur)
          _buildBottomSummary(),
        ],
      ),
    );
  }

  Widget _buildBottomSummary() {
    final owned = _buildings
        .map((b) => (name: b.name, emoji: b.emoji, count: _getCount(b.name)))
        .where((b) => b.count > 0)
        .toList();

    return Container(
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
            children: owned
                .map(
                  (b) => Text(
                    '${b.emoji} ${b.name}: ${b.count}',
                    style: TextStyle(fontSize: 14, color: Colors.brown[600]),
                  ),
                )
                .toList(),
          ),
          if (owned.isEmpty)
            Text(
              'No buildings yet. Buy one above!',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey[500],
              ),
            ),
        ],
      ),
    );
  }
}

class _BuildingInfo {
  final String name;
  final String emoji;
  final String description;
  final int baseCost;
  final String type; // 'factory', 'warehouse' or 'depot'

  const _BuildingInfo({
    required this.name,
    required this.emoji,
    required this.description,
    required this.baseCost,
    required this.type,
  });
}
