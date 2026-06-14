import 'package:flutter/material.dart';
import 'package:zelix_rised_trades/core/engine/game_engine.dart';
import 'package:zelix_rised_trades/core/enums/factory_type.dart';
import 'package:zelix_rised_trades/core/models/factory.dart' as models;
import 'package:zelix_rised_trades/core/models/warehouse.dart';
import 'package:zelix_rised_trades/screens/building_shop_screen.dart';
import 'package:zelix_rised_trades/screens/warehouse_screen.dart';

/// Factory Screen - Tüm factory ve warehouse'ları gösterir.
class FactoryScreen extends StatefulWidget {
  final String warehouseId;

  const FactoryScreen({
    super.key,
    required this.warehouseId,
  });

  @override
  State<FactoryScreen> createState() => _FactoryScreenState();
}

class _FactoryScreenState extends State<FactoryScreen> {
  final GameEngine _engine = GameEngine();
  List<models.Factory> _factories = [];
  List<Warehouse> _allWarehouses = [];
  String _selectedWarehouseId = "w1";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _engine.factoriesNotifier.addListener(_onDataChanged);
    _engine.warehousesNotifier.addListener(_onDataChanged);
    _engine.tickNotifier.addListener(_onTick);
    _engine.stateVersion.addListener(_onDataChanged);
    _selectedWarehouseId = widget.warehouseId;
    _loadData();
  }

  @override
  void dispose() {
    _engine.factoriesNotifier.removeListener(_onDataChanged);
    _engine.warehousesNotifier.removeListener(_onDataChanged);
    _engine.tickNotifier.removeListener(_onTick);
    _engine.stateVersion.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (!mounted) return;
    setState(() {
      _factories = _engine.factoriesNotifier.value;
      _allWarehouses = _engine.getAllWarehouses();
    });
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  void _loadData() {
    _factories = _engine.factoriesNotifier.value;
    _allWarehouses = _engine.getAllWarehouses();
    
    // Seçili warehouse yoksa ilkini kullan
    if (_allWarehouses.isNotEmpty && !_allWarehouses.any((w) => w.id == _selectedWarehouseId)) {
      _selectedWarehouseId = _allWarehouses.first.id;
    }
    
    _isLoading = false;
  }

  Warehouse? get _warehouse {
    try {
      return _allWarehouses.firstWhere((w) => w.id == _selectedWarehouseId);
    } catch (_) {
      return _allWarehouses.isNotEmpty ? _allWarehouses.first : null;
    }
  }

  String _getFactoryEmoji(FactoryType type) {
    switch (type) {
      case FactoryType.forest: return '🌲';
      case FactoryType.lumberMill: return '🪚';
      case FactoryType.furnitureFactory: return '🪑';
    }
  }

  String _getFactoryDescription(FactoryType type) {
    switch (type) {
      case FactoryType.forest: return 'Produces 5 Wood every ${type.productionSeconds}s · Upkeep ¥${type.upkeepCost}';
      case FactoryType.lumberMill: return 'Converts 10 Wood → 5 Lumber every ${type.productionSeconds}s · Upkeep ¥${type.upkeepCost}';
      case FactoryType.furnitureFactory: return 'Converts 10 Lumber → 2 Furniture every ${type.productionSeconds}s · Upkeep ¥${type.upkeepCost}';
    }
  }

  void _toggleFactory(models.Factory factory) {
    _engine.toggleFactory(factory.id);
  }

  void _manualProduce(models.Factory factory) {
    final wh = _warehouse;
    if (wh == null) return;

    if (factory.type.input != null) {
      if (wh.get(factory.type.input!) < factory.type.inputAmount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Not enough ${factory.type.input!.name}!'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    if (factory.type.input != null) {
      _engine.removeResourceFromWarehouse(
        _selectedWarehouseId,
        factory.type.input!,
        factory.type.inputAmount,
        reason: '${factory.type.name} manual production',
      );
    }

    _engine.addResourceToWarehouse(
      _selectedWarehouseId,
      factory.type.output,
      factory.type.outputAmount,
      reason: '${factory.type.name} manual production',
    );

    factory.lastProduction = DateTime.now();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_getFactoryEmoji(factory.type)} ${factory.type.name} produced!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Color _getFactoryColor(FactoryType type) {
    switch (type) {
      case FactoryType.forest: return Colors.green;
      case FactoryType.lumberMill: return Colors.brown;
      case FactoryType.furnitureFactory: return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final wh = _warehouse;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Factories', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 24, letterSpacing: 1.5, fontStyle: FontStyle.italic)),
        centerTitle: true,
        backgroundColor: Colors.teal[50],
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart, color: Colors.black54),
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const BuildingShopScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.warehouse, color: Colors.black54),
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => WarehouseScreen(warehouseId: _selectedWarehouseId)),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Warehouse selector strip
                if (_allWarehouses.length > 1)
                  Container(
                    height: 48,
                    color: Colors.teal[50],
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _allWarehouses.length,
                      itemBuilder: (context, index) {
                        final w = _allWarehouses[index];
                        final isSelected = w.id == _selectedWarehouseId;
                        final isFull = w.freeCapacity < 10;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warehouse, size: 16, color: isFull ? Colors.red : Colors.teal),
                                const SizedBox(width: 4),
                                Text('${w.name} (${w.usedCapacity})', style: TextStyle(fontSize: 12, color: isFull ? Colors.red : null)),
                              ],
                            ),
                            selected: isSelected,
                            selectedColor: Colors.teal[200],
                            onSelected: (_) => setState(() => _selectedWarehouseId = w.id),
                          ),
                        );
                      },
                    ),
                  ),
                // Warehouse capacity indicator
                if (wh != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: Colors.teal[50],
                    child: Row(
                      children: [
                        const Icon(Icons.inventory, color: Colors.teal),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${wh.name} (${wh.id})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: wh.capacity > 0 ? wh.usedCapacity / wh.capacity : 0,
                                minHeight: 8,
                                backgroundColor: Colors.teal[100],
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                              ),
                              Text('${wh.usedCapacity} / ${wh.capacity}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                // Factory list
                Expanded(
                  child: _factories.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🏭', style: TextStyle(fontSize: 64)),
                              const SizedBox(height: 16),
                              Text('No factories yet!', style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text('Buy factories from the Building Shop', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () => Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(builder: (context) => const BuildingShopScreen()),
                                ),
                                icon: const Icon(Icons.shopping_cart),
                                label: const Text('Go to Shop'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _factories.length,
                          itemBuilder: (context, index) {
                            final factory = _factories[index];
                            final color = _getFactoryColor(factory.type);
                            final now = DateTime.now();
                            final elapsed = now.difference(factory.lastProduction).inSeconds;
                            final progress = factory.type.productionSeconds > 0
                                ? (elapsed / factory.type.productionSeconds).clamp(0.0, 1.0)
                                : 0.0;
                            final timeLeft = factory.active
                                ? (factory.type.productionSeconds - elapsed).clamp(0, factory.type.productionSeconds)
                                : factory.type.productionSeconds;
                            final canRun = factory.active && timeLeft <= 0;

                            bool hasInput = true;
                            if (wh != null && factory.type.input != null) {
                              hasInput = wh.get(factory.type.input!) >= factory.type.inputAmount;
                            }
                            final noInput = factory.active && canRun && !hasInput;

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: noInput ? Colors.red[300]! : (factory.active ? color : Colors.grey[300]!),
                                  width: noInput ? 2 : (factory.active ? 1.5 : 1),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(_getFactoryEmoji(factory.type), style: const TextStyle(fontSize: 32)),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(factory.type.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                                              Text(_getFactoryDescription(factory.type), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                            ],
                                          ),
                                        ),
                                        Switch(
                                          value: factory.active,
                                          activeTrackColor: color.withValues(alpha: 0.5),
                                          activeThumbColor: color,
                                          onChanged: (_) => _toggleFactory(factory),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                                      child: Row(
                                        children: [
                                          if (factory.type.input != null) ...[
                                            Icon(Icons.arrow_downward, size: 16, color: hasInput ? Colors.green[400] : Colors.red[400]),
                                            const SizedBox(width: 4),
                                            Text('${factory.type.inputAmount} ${factory.type.input!.name}',
                                              style: TextStyle(fontSize: 13, color: hasInput ? Colors.green[700] : Colors.red[400], fontWeight: FontWeight.w500)),
                                            const SizedBox(width: 8),
                                            Icon(Icons.arrow_forward, size: 16, color: Colors.grey[500]),
                                            const SizedBox(width: 8),
                                          ],
                                          Icon(Icons.arrow_upward, size: 16, color: Colors.green[400]),
                                          const SizedBox(width: 4),
                                          Text('+${factory.type.outputAmount} ${factory.type.output.name}',
                                            style: TextStyle(fontSize: 13, color: Colors.green[700], fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                                    ),
                                    if (factory.active) ...[
                                      const SizedBox(height: 12),
                                      SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          activeTrackColor: color,
                                          inactiveTrackColor: color.withValues(alpha: 0.2),
                                          thumbColor: color,
                                          overlayColor: color.withValues(alpha: 0.1),
                                          trackHeight: 8,
                                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                                        ),
                                        child: Slider(value: progress, min: 0, max: 1, onChanged: null),
                                      ),
                                      Row(
                                        children: [
                                          Icon(Icons.timer_outlined, size: 14, color: Colors.grey[500]),
                                          const SizedBox(width: 4),
                                          Text(canRun ? 'Ready!' : '${timeLeft}s remaining',
                                            style: TextStyle(fontSize: 12, color: canRun ? Colors.green[700] : Colors.grey[600],
                                              fontWeight: canRun ? FontWeight.bold : FontWeight.normal)),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Container(width: 10, height: 10,
                                                decoration: BoxDecoration(shape: BoxShape.circle,
                                                  color: !factory.active ? Colors.grey[400] : (noInput ? Colors.red : (canRun ? Colors.green : color))),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(!factory.active ? 'Stopped' : (noInput ? 'Missing Input!' : (canRun ? 'Running' : 'Processing')),
                                                style: TextStyle(fontSize: 13, color: noInput ? Colors.red[600] : Colors.grey[600],
                                                  fontWeight: noInput ? FontWeight.bold : FontWeight.normal)),
                                            ],
                                          ),
                                        ),
                                        if (canRun)
                                          ElevatedButton.icon(
                                            onPressed: hasInput ? () => _manualProduce(factory) : null,
                                            icon: Icon(Icons.play_arrow, size: 18, color: hasInput ? Colors.white : Colors.grey),
                                            label: Text(hasInput ? 'Run Now' : 'No Input',
                                              style: TextStyle(fontSize: 13, color: hasInput ? Colors.white : Colors.grey[500])),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: hasInput ? color : null,
                                              disabledBackgroundColor: Colors.grey[200],
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}