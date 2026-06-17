import 'package:flutter/material.dart';
import 'package:zelix_rised_trades/core/database/truck_db.dart';
import 'package:zelix_rised_trades/core/engine/game_engine.dart';
import 'package:zelix_rised_trades/core/models/truck_spec.dart';
import 'package:zelix_rised_trades/screens/truck_management_screen.dart';

/// Truck Catalog Screen - Sadece satın alma kataloğu
/// Para yettiği sürece her tipten sınırsız satın alınabilir.
class TruckCatalogScreen extends StatefulWidget {
  const TruckCatalogScreen({super.key});

  @override
  State<TruckCatalogScreen> createState() => _TruckCatalogScreenState();
}

class _TruckCatalogScreenState extends State<TruckCatalogScreen> {
  final GameEngine _engine = GameEngine();

  int _playerMoney = 0;
  int _ownedCount(String typeId) =>
      _engine.state.trucks.where((t) => t.typeId == typeId).length;

  @override
  void initState() {
    super.initState();
    _engine.stateVersion.addListener(_onDataChanged);
    _engine.moneyNotifier.addListener(_onDataChanged);
    _refresh();
  }

  @override
  void dispose() {
    _engine.stateVersion.removeListener(_onDataChanged);
    _engine.moneyNotifier.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (!mounted) return;
    _refresh();
  }

  void _refresh() {
    _playerMoney = _engine.state.player.money;
    setState(() {});
  }

  bool _canBuySpec(TruckSpec spec) => _engine.canAfford(spec.price);

  String _moneyFormatted(int amount) {
    if (amount >= 1000000) {
      return '¥${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '¥${(amount / 1000).toStringAsFixed(0)}K';
    }
    return '¥$amount';
  }

  void _buyTruck(TruckSpec spec) {
    if (!_canBuySpec(spec)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('💰 Need ${_moneyFormatted(spec.price)}!'),
          backgroundColor: Colors.red[300],
        ),
      );
      return;
    }

    final ok = _engine.buyTruck(spec.id);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${spec.name} purchased! (x${_ownedCount(spec.id)})'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  IconData _truckIcon(String typeId) {
    switch (typeId) {
      case 'small':
        return Icons.local_shipping;
      case 'medium':
        return Icons.local_shipping;
      case 'large':
        return Icons.fire_truck;
      default:
        return Icons.local_shipping;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Truck Catalog'),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on,
                      size: 18, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    _moneyFormatted(_playerMoney),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Manage Trucks',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const TruckManagementScreen(),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.store, color: Colors.teal[700], size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Buy New Trucks',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Unlimited purchase - buy as many as you want',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...TruckCatalog.trucks.map((spec) => _buildCatalogCard(spec)),
          const SizedBox(height: 24),
          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TruckManagementScreen(),
                ),
              ),
              icon: const Icon(Icons.local_shipping),
              label: const Text('Go to Truck Management'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogCard(TruckSpec spec) {
    final canBuy = _canBuySpec(spec);
    final count = _ownedCount(spec.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _truckIcon(spec.id),
                    color: Colors.teal[700],
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spec.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (spec.description.isNotEmpty)
                        Text(
                          spec.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on,
                          size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        _moneyFormatted(spec.price),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.brown,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildStatChip(Icons.inventory, 'Cap', '${spec.baseCapacity}'),
                const SizedBox(width: 0.4),
                _buildStatChip(Icons.speed, 'Speed', '${spec.baseSpeed}'),
                const SizedBox(width: 0.4),
                _buildStatChip(
                  Icons.check_circle,
                  'Reliability',
                  '${(spec.baseReliability * 100).toInt()}%',
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Owned count + Buy button
            Row(
              children: [
                if (count > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Owned: x$count',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[700],
                      ),
                    ),
                  ),
                const Spacer(),
                SizedBox(
                  width: 160,
                  child: ElevatedButton.icon(
                    onPressed: canBuy ? () => _buyTruck(spec) : null,
                    icon: const Icon(Icons.add_shopping_cart, size: 20),
                    label: Text(
                      'Buy ${_moneyFormatted(spec.price)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          canBuy ? Colors.teal : Colors.grey[300],
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[200],
                      disabledForegroundColor: Colors.grey[400],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, String value,
      {Color color = Colors.teal}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}