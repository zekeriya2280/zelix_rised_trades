import 'package:flutter/material.dart';
import 'package:zelix_rised_trades/core/engine/game_engine.dart';
import 'package:zelix_rised_trades/core/enums/resource_type.dart';
import 'package:zelix_rised_trades/core/models/warehouse.dart';
import 'package:zelix_rised_trades/screens/building_shop_screen.dart';
import 'package:zelix_rised_trades/screens/factory_screen.dart';


/// Warehouse Screen - Tüm warehouse'ları listeler, üstte toplu özet gösterir.
class WarehouseScreen extends StatefulWidget {
  final String warehouseId;

  const WarehouseScreen({super.key, required this.warehouseId});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  final GameEngine _engine = GameEngine();
  List<Warehouse> _allWarehouses = [];
  String? _selectedWarehouseId;
  bool _confirmedEmpty = false;

  @override
  void initState() {
    super.initState();
    _engine.warehousesNotifier.addListener(_onDataChanged);
    _engine.stateVersion.addListener(_onDataChanged);

    _allWarehouses = _engine.getAllWarehouses();

    if (_allWarehouses.isEmpty) {
      _updateConfirmedEmpty();
    } else {
      _selectInitialWarehouse();
      _updateConfirmedEmpty();
    }

  }

  // Engine-only: Hive'a direkt erişim yok.
  // _confirmedEmpty, engine state'e göre hesaplanır.
  void _updateConfirmedEmpty() {
    _confirmedEmpty = _allWarehouses.isEmpty;
  }


  void _selectInitialWarehouse() {
    _selectedWarehouseId = widget.warehouseId;
    if (!_allWarehouses.any((w) => w.id == _selectedWarehouseId)) {
      _selectedWarehouseId = _allWarehouses.isNotEmpty ? _allWarehouses.first.id : null;
    }
  }

  @override
  void dispose() {
    _engine.warehousesNotifier.removeListener(_onDataChanged);
    _engine.stateVersion.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (!mounted) return;
    final current = _engine.getAllWarehouses();
    if (current.isNotEmpty || _allWarehouses.isEmpty) {
      setState(() {
        _allWarehouses = current;
        if (current.isEmpty) {
          _confirmedEmpty = true;
        } else if (_selectedWarehouseId == null || !current.any((w) => w.id == _selectedWarehouseId)) {
          _selectedWarehouseId = current.first.id;
        }
      });
    }
  }

  // ---- Özet Hesaplamaları ----

  int get _totalWood => _allWarehouses.fold(0, (s, w) => s + w.get(ResourceType.wood));
  int get _totalLumber => _allWarehouses.fold(0, (s, w) => s + w.get(ResourceType.lumber));
  int get _totalFurniture => _allWarehouses.fold(0, (s, w) => s + w.get(ResourceType.furniture));
  int get _totalUsed => _allWarehouses.fold(0, (s, w) => s + w.usedCapacity);
  int get _totalCapacity => _allWarehouses.fold(0, (s, w) => s + w.capacity);
  double get _totalCapPercent => _totalCapacity > 0 ? _totalUsed / _totalCapacity : 0.0;

  // ---- UI ----

  Color _resColor(ResourceType t) =>
      switch (t) { ResourceType.wood => Colors.green, ResourceType.lumber => Colors.brown, ResourceType.furniture => Colors.orange };

  String _resEmoji(ResourceType t) =>
      switch (t) { ResourceType.wood => '🌲', ResourceType.lumber => '🪚', ResourceType.furniture => '🪑' };

  /// Üstteki toplu özet kartı
  Widget _buildSummaryCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık + warehouse sayısı
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.inventory_2, color: Colors.teal, size: 22),
                ),
                const SizedBox(width: 12),
                Text('Total Storage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.teal[50], borderRadius: BorderRadius.circular(20)),
                  child: Text('${_allWarehouses.length} WH', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal[700])),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Toplam kapasite barı
            LinearProgressIndicator(
              value: _totalCapPercent, minHeight: 8,
              backgroundColor: Colors.teal[100],
              valueColor: AlwaysStoppedAnimation<Color>(_totalCapPercent > 0.9 ? Colors.red : Colors.teal),
            ),
            const SizedBox(height: 6),
            Text('$_totalUsed / $_totalCapacity used', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 12),
            // Kaynak bazında toplamlar
            Row(
              children: [
                _buildResourceStat(ResourceType.wood, _totalWood, Icons.arrow_downward, Colors.green),
                const SizedBox(width: 8),
                _buildResourceStat(ResourceType.lumber, _totalLumber, Icons.arrow_downward, Colors.brown),
                const SizedBox(width: 8),
                _buildResourceStat(ResourceType.furniture, _totalFurniture, Icons.arrow_downward, Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceStat(ResourceType type, int amount, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(_resEmoji(type), style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text('$amount', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(type.name, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildWarehouseCard(Warehouse w) {
    final isSelected = w.id == _selectedWarehouseId;
    final used = w.usedCapacity;
    final capPct = w.capacity > 0 ? used / w.capacity : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isSelected ? Colors.teal : Colors.grey[300]!, width: isSelected ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _selectedWarehouseId = w.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.warehouse, color: Colors.teal, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(w.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${w.type} | Truck: ${w.truckCapacity}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(w.id, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: capPct > 0.9 ? Colors.red[50] : Colors.teal[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$used / ${w.capacity}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: capPct > 0.9 ? Colors.red[700] : Colors.teal[700])),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: capPct, minHeight: 6,
                backgroundColor: Colors.teal[100],
                valueColor: AlwaysStoppedAnimation<Color>(capPct > 0.9 ? Colors.red : Colors.teal),
              ),
              const SizedBox(height: 8),
              Row(
                children: ResourceType.values.map((type) {
                  final amt = w.get(type);
                  return Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_resEmoji(type), style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                        Text('$amt', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _resColor(type))),
                      ],
                    ),
                  );
                }).toList(),
              ),
              if (isSelected && w.logs.isNotEmpty) ...[
                const SizedBox(height: 8), const Divider(), const SizedBox(height: 8),
                const Text('Recent Activity', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ...w.logs.take(5).map((log) {
                  final op = log.operation == 'in' ? '+' : (log.operation == 'out' ? '-' : '');
                  final amt = log.amount > 0 ? '$op${log.amount}' : '';
                  final time = '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(log.operation == 'in' ? Icons.arrow_downward : (log.operation == 'out' ? Icons.arrow_upward : Icons.info_outline), size: 14,
                          color: log.operation == 'in' ? Colors.green : (log.operation == 'out' ? Colors.red : Colors.blue)),
                        const SizedBox(width: 4),
                        Expanded(child: Text('${log.reason} $amt', style: TextStyle(fontSize: 11, color: Colors.grey[600]))),
                        Text(time, style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                      ],
                    ),
                  );
                }),
              ],
              if (isSelected && w.logs.isEmpty)
                Padding(padding: const EdgeInsets.only(top: 8),
                  child: Text('No activity', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey[400]))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.factory, color: Colors.black54),
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => FactoryScreen(warehouseId: _selectedWarehouseId ?? widget.warehouseId)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart, color: Colors.black54),
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const BuildingShopScreen()),
            ),
          ),
        ],
        title: const Center(
          child: Text('Warehouses', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 30, letterSpacing: 1.5, fontStyle: FontStyle.italic)),
        ),
      ),
      body: _allWarehouses.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warehouse_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(_confirmedEmpty ? 'No warehouses yet' : 'Loading...',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                  Text(_confirmedEmpty ? 'Buy one from the Building Shop' : '',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                  if (!_confirmedEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey[400])),
                  ],
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async => setState(() => _allWarehouses = _engine.getAllWarehouses()),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  // === TOPLU ÖZET KARTI ===
                  _buildSummaryCard(),
                  const SizedBox(height: 8),
                  // Warehouse listesi başlığı
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Icon(Icons.warehouse, size: 18, color: Colors.teal),
                        const SizedBox(width: 6),
                        Text('Warehouses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                        const Spacer(),
                        Text('${_allWarehouses.length} total', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Tek tek warehouse kartları
                  ..._allWarehouses.map((w) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildWarehouseCard(w),
                  )),
                ],
              ),
            ),
    );
  }
}