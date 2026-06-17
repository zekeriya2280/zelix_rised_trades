import 'package:flutter/material.dart';
import 'package:zelix_rised_trades/core/engine/game_engine.dart';
import 'package:zelix_rised_trades/core/models/truck.dart';
import 'package:zelix_rised_trades/screens/truck_catalog_screen.dart';

/// Truck Management Screen - Tüm truck'lar büyük kart, seçilene action butonları
class TruckManagementScreen extends StatefulWidget {
  const TruckManagementScreen({super.key});

  @override
  State<TruckManagementScreen> createState() => _TruckManagementScreenState();
}

class _TruckManagementScreenState extends State<TruckManagementScreen> {
  final GameEngine _engine = GameEngine();

  List<Truck> _trucks = [];
  String? _selectedTruckId;
  int _playerMoney = 0;

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
    _trucks = _engine.state.trucks;
    _playerMoney = _engine.state.player.money;
    if (_selectedTruckId == null ||
        !_trucks.any((t) => t.id == _selectedTruckId)) {
      _selectedTruckId = _trucks.isNotEmpty ? _trucks.first.id : null;
    }
    setState(() {});
  }

  bool _isWornOut(Truck truck) => truck.durability <= 60;

  void _showSnack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: bg,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _moneyFormatted(int amount) {
    if (amount >= 1000000) return '¥${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '¥${(amount / 1000).toStringAsFixed(0)}K';
    return '¥$amount';
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Truck Management (${_trucks.length})'),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
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
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.store),
            tooltip: 'Buy Trucks',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TruckCatalogScreen()),
            ),
          ),
        ],
      ),
      body: _trucks.isEmpty
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _trucks.map((t) {
                final isSelected = t.id == _selectedTruckId;
                return _buildTruckCard(t, isSelected);
              }).toList(),
            ),
    );
  }

  // ============ BÜYÜK TRUCK KARTI ============

  Widget _buildTruckCard(Truck truck, bool isSelected) {
    final wornOut = _isWornOut(truck);
    final hpColor = truck.durability > 70
        ? Colors.green
        : (truck.durability > 40 ? Colors.orange : Colors.red);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: wornOut
              ? Colors.red
              : (isSelected ? Colors.teal : Colors.grey[300]!),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _selectedTruckId = truck.id),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                wornOut
                    ? Colors.red[50]!
                    : (isSelected
                        ? Colors.teal[50]!
                        : Colors.grey[50]!),
                Colors.white,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Üst: icon + isim + level + STATUS
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.local_shipping,
                          color: Colors.teal, size: 30),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(truck.name,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          Text('ID: ${truck.id}',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[500],
                                  fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                    _badge('Lv.${truck.level}',
                        Colors.purple.withValues(alpha: 0.1),
                        Colors.purple[700]!),
                    const SizedBox(width: 8),
                    _buildStatusBadge(truck.status, large: true),
                  ],
                ),
                const SizedBox(height: 12),

                // İstatistikler
                Row(
                  children: [
                    _stat(Icons.inventory, 'Cap',
                        '${truck.effectiveCapacity}', Colors.teal),
                    const SizedBox(width: 16),
                    _stat(Icons.speed, 'Spd',
                        truck.effectiveSpeed.toStringAsFixed(1),
                        Colors.blue),
                    const SizedBox(width: 16),
                    _stat(Icons.warning_amber, 'Fail',
                        '${(truck.failureChance * 100).toInt()}%',
                        Colors.red),
                  ],
                ),
                const SizedBox(height: 10),

                // HP bar
                Row(
                  children: [
                    Icon(Icons.favorite, size: 16, color: hpColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: truck.durability / 100.0,
                        minHeight: 8,
                        backgroundColor: Colors.grey[200],
                        valueColor:
                            AlwaysStoppedAnimation<Color>(hpColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${truck.durability}/100',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: hpColor)),
                    const SizedBox(width: 16),
                    Icon(Icons.route, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text('${truck.mileage} km',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[500])),
                  ],
                ),

                // Uyarı
                if (wornOut)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning,
                              size: 18, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '⚠️ Failure: '
                              '${(truck.failureChance * 100).toInt()}%. '
                              'Repair or Sell.',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Seçiliyse action butonları
                if (isSelected) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _actionBtn(
                            Icons.build, 'Repair', Colors.orange, () {
                          _engine.repairTruck(truck.id);
                          _showSnack(
                              '🔧 ${truck.name} repaired!', Colors.orange);
                        }),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _actionBtn(Icons.arrow_upward,
                            'Upgrade', Colors.purple, () {
                          _engine.upgradeTruck(truck.id);
                          _showSnack(
                              '⬆ ${truck.name} → Lv.${truck.level + 1}!',
                              Colors.purple);
                        }),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _actionBtn(
                            Icons.sell, 'Sell', Colors.red, () {
                          _engine.sellTruck(truck.id);
                          _showSnack(
                              '💰 ${truck.name} sold!', Colors.red);
                        }),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============ STATÜ BADGE ============

  Widget _buildStatusBadge(TruckStatus status, {bool large = false}) {
    final color = _statusColor(status);
    final icon = _statusIcon(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 14 : 8,
        vertical: large ? 8 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: large ? 18 : 12, color: color),
          const SizedBox(width: 3),
          Text(
            status.name.toUpperCase(),
            style: TextStyle(
              fontSize: large ? 13 : 9,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(TruckStatus status) {
    switch (status) {
      case TruckStatus.idle:
        return Colors.grey;
      case TruckStatus.loading:
        return Colors.blue;
      case TruckStatus.moving:
        return Colors.green;
      case TruckStatus.unloading:
        return Colors.teal;
      case TruckStatus.broken:
        return Colors.red;
      case TruckStatus.maintenance:
        return Colors.orange;
    }
  }

  IconData _statusIcon(TruckStatus status) {
    switch (status) {
      case TruckStatus.idle:
        return Icons.hourglass_empty;
      case TruckStatus.loading:
        return Icons.downloading;
      case TruckStatus.moving:
        return Icons.directions_car;
      case TruckStatus.unloading:
        return Icons.upload;
      case TruckStatus.broken:
        return Icons.error;
      case TruckStatus.maintenance:
        return Icons.build;
    }
  }

  // ============ HELPERS ============

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13, color: fg)),
    );
  }

  Widget _stat(IconData icon, String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text('$label: $value',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color)),
      ],
    );
  }

  Widget _actionBtn(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 42,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 11)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_shipping, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No trucks!',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[500])),
          const SizedBox(height: 8),
          Text('Buy one from the catalog',
              style: TextStyle(fontSize: 14, color: Colors.grey[400])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const TruckCatalogScreen()),
            ),
            icon: const Icon(Icons.store),
            label: const Text('Go to Catalog'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}