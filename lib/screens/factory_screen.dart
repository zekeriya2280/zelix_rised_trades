import 'package:flutter/material.dart';
import 'package:zelix_rised_trades/core/engine/game_engine.dart';
import 'package:zelix_rised_trades/core/enums/factory_type.dart';
import 'package:zelix_rised_trades/core/enums/resource_type.dart';
import 'package:zelix_rised_trades/core/models/factory.dart';
import 'package:zelix_rised_trades/core/models/warehouse.dart';
import 'package:zelix_rised_trades/core/services/firestore_service.dart';
import 'package:zelix_rised_trades/screens/building_shop_screen.dart';

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
  final FirestoreService _firestore = FirestoreService();
  final GameEngine _engine = GameEngine();
  List<Factory> _factories = [];
  Warehouse? _warehouse;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Subscribe to GameEngine's reactive notifiers instead of using local timers.
    // The engine streams factories & warehouses from Firebase in real-time.
    _engine.factoriesNotifier.addListener(_onFactoriesChanged);
    _engine.warehousesNotifier.addListener(_onWarehousesChanged);
    _engine.tickNotifier.addListener(_onTick);
    _ensureWarehouseExists();
  }

  @override
  void dispose() {
    _engine.factoriesNotifier.removeListener(_onFactoriesChanged);
    _engine.warehousesNotifier.removeListener(_onWarehousesChanged);
    _engine.tickNotifier.removeListener(_onTick);
    super.dispose();
  }

  void _onFactoriesChanged() {
    if (!mounted) return;
    setState(() {
      _factories = _engine.factoriesNotifier.value;
    });
  }

  void _onWarehousesChanged() {
    if (!mounted) return;
    final warehouses = _engine.warehousesNotifier.value;
    _warehouse = warehouses[widget.warehouseId];
    // If we have data, we're no longer loading
    if (_isLoading && _warehouse != null) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Called on every 1s engine tick to update progress bars / sliders.
  void _onTick() {
    if (mounted) setState(() {});
  }

  /// Ensure the warehouse exists in Firebase. The engine's listeners will pick
  /// it up once saved.
  Future<void> _ensureWarehouseExists() async {
    try {
      Warehouse? warehouse = await _firestore
          .getWarehouse(widget.warehouseId)
          .timeout(const Duration(seconds: 10));

      if (warehouse == null) {
        warehouse = Warehouse(
          id: widget.warehouseId,
          name: 'Main Warehouse',
          capacity: 500,
          stock: {
            ResourceType.wood: 5,
            ResourceType.lumber: 0,
            ResourceType.furniture: 0,
          },
        );
        await _firestore.saveWarehouse(warehouse);
      }

      // Mark loading complete regardless
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Warehouse loading failed: $e');
      // Create a fallback warehouse for offline use
      if (mounted) {
        setState(() {
          _warehouse = Warehouse(
            id: widget.warehouseId,
            name: 'Main Warehouse',
            capacity: 500,
            stock: {
              ResourceType.wood: 5,
              ResourceType.lumber: 0,
              ResourceType.furniture: 0,
            },
          );
          _isLoading = false;
        });
      }
    }
  }

  String _getFactoryEmoji(FactoryType type) {
    switch (type) {
      case FactoryType.forest:
        return '🌲';
      case FactoryType.lumberMill:
        return '🪚';
      case FactoryType.furnitureFactory:
        return '🪑';
    }
  }

  String _getFactoryDescription(FactoryType type) {
    switch (type) {
      case FactoryType.forest:
        return 'Produces 5 Wood every ${type.productionSeconds}s · Upkeep ¥${type.upkeepCost}';
      case FactoryType.lumberMill:
        return 'Converts 10 Wood → 5 Lumber every ${type.productionSeconds}s · Upkeep ¥${type.upkeepCost}';
      case FactoryType.furnitureFactory:
        return 'Converts 10 Lumber → 2 Furniture every ${type.productionSeconds}s · Upkeep ¥${type.upkeepCost}';
    }
  }

  void _toggleFactory(Factory factory) async {
    setState(() {
      factory.active = !factory.active;
    });
    await _firestore.saveFactory(factory);
  }

  Future<void> _saveFactories() async {
    for (final factory in _factories) {
      await _firestore.saveFactory(factory);
    }
  }

  Future<void> _saveWarehouse() async {
    if (_warehouse == null) return;
    await _firestore.saveWarehouse(_warehouse!);
    await _firestore.updateWarehouseStock(
      _warehouse!.id,
      _warehouse!.stock.map((key, value) => MapEntry(key.name, value)),
    );
  }

  void _manualProduce(Factory factory) async {
    if (_warehouse == null) return;
    setState(() {
      factory.update(_warehouse!);
    });
    await _saveFactories();
    await _saveWarehouse();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_getFactoryEmoji(factory.type)} ${factory.type.name} produced!',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Color _getFactoryColor(FactoryType type) {
    switch (type) {
      case FactoryType.forest:
        return Colors.green;
      case FactoryType.lumberMill:
        return Colors.brown;
      case FactoryType.furnitureFactory:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Factories',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontSize: 24,
            letterSpacing: 1.5,
            fontStyle: FontStyle.italic,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.teal[50],
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart, color: Colors.black54),
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const BuildingShopScreen(),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading || _warehouse == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Warehouse capacity indicator
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.teal[50],
                  child: Row(
                    children: [
                      const Icon(Icons.inventory, color: Colors.teal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _warehouse!.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: _warehouse!.capacity > 0
                                  ? _warehouse!.usedCapacity /
                                      _warehouse!.capacity
                                  : 0,
                              minHeight: 8,
                              backgroundColor: Colors.teal[100],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.teal),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_warehouse!.usedCapacity} / ${_warehouse!.capacity}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Factory list
                Expanded(
                  child: _factories.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🏭', style: TextStyle(fontSize: 64)),
                              const SizedBox(height: 16),
                              Text(
                                'No factories yet!',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Buy factories from the Building Shop',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const BuildingShopScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.shopping_cart),
                                label: const Text('Go to Shop'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _factories.length,
                          itemBuilder: (context, index) {
                            final factory = _factories[index];
                            final color = _getFactoryColor(factory.type);
                            final now = DateTime.now();
                            final elapsed = now
                                .difference(factory.lastProduction)
                                .inSeconds;
                            final progress =
                                factory.type.productionSeconds > 0
                                    ? (elapsed /
                                            factory.type.productionSeconds)
                                        .clamp(0.0, 1.0)
                                    : 0.0;
                            final timeLeft = factory.active
                                ? (factory.type.productionSeconds - elapsed)
                                    .clamp(0, factory.type.productionSeconds)
                                : factory.type.productionSeconds;
                            final canRun =
                                factory.active && timeLeft <= 0;

                            // Check if enough input resources
                            bool hasInput = true;
                            if (factory.type.input != null) {
                              hasInput =
                                  _warehouse!.get(factory.type.input!) >=
                                      factory.type.inputAmount;
                            }
                            final noInput =
                                factory.active && canRun && !hasInput;

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 6),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(16),
                                side: BorderSide(
                                  color: noInput
                                      ? Colors.red[300]!
                                      : (factory.active
                                          ? color
                                          : Colors.grey[300]!),
                                  width: noInput
                                      ? 2
                                      : (factory.active ? 1.5 : 1),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    // Header row
                                    Row(
                                      children: [
                                        Text(
                                          _getFactoryEmoji(factory.type),
                                          style: const TextStyle(
                                              fontSize: 32),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment
                                                    .start,
                                            children: [
                                              Text(
                                                factory.type.name,
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  color:
                                                      Colors.grey[800],
                                                ),
                                              ),
                                              Text(
                                                _getFactoryDescription(
                                                    factory.type),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Active toggle
                                        Switch(
                                          value: factory.active,
                                          activeTrackColor: color
                                              .withValues(alpha: 0.5),
                                          activeThumbColor: color,
                                          onChanged: (_) =>
                                              _toggleFactory(factory),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 8),

                                    // Input/Output info
                                    Container(
                                      padding: const EdgeInsets.all(
                                          10),
                                      decoration: BoxDecoration(
                                        color: color.withValues(
                                            alpha: 0.08),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          if (factory.type.input !=
                                              null) ...[
                                            Icon(
                                                Icons.arrow_downward,
                                                size: 16,
                                                color: hasInput
                                                    ? Colors
                                                        .green[400]
                                                    : Colors
                                                        .red[400]),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${factory.type.inputAmount} ${factory.type.input!.name}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: hasInput
                                                    ? Colors
                                                        .green[700]
                                                    : Colors
                                                        .red[400],
                                                fontWeight:
                                                    FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                                Icons.arrow_forward,
                                                size: 16,
                                                color:
                                                    Colors.grey[500]),
                                            const SizedBox(width: 8),
                                          ],
                                          Icon(Icons.arrow_upward,
                                              size: 16,
                                              color:
                                                  Colors.green[400]),
                                          const SizedBox(width: 4),
                                          Text(
                                            '+${factory.type.outputAmount} ${factory.type.output.name}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.green[700],
                                              fontWeight:
                                                  FontWeight.w500,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (factory.efficiency != 1)
                                            Container(
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color:
                                                    Colors.amber[100],
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(6),
                                              ),
                                              child: Text(
                                                '${(factory.efficiency * 100).round()}%',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      Colors.amber[800],
                                                  fontWeight:
                                                      FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 12),

                                    // Production slider - updates every 1 second
                                    if (factory.active)
                                      Column(
                                        children: [
                                          SliderTheme(
                                            data: SliderTheme.of(
                                                    context)
                                                .copyWith(
                                              activeTrackColor:
                                                  color,
                                              inactiveTrackColor: color
                                                  .withValues(
                                                      alpha: 0.2),
                                              thumbColor: color,
                                              overlayColor: color
                                                  .withValues(
                                                      alpha: 0.1),
                                              trackHeight: 8,
                                              thumbShape:
                                                  const RoundSliderThumbShape(
                                                      enabledThumbRadius:
                                                          10),
                                            ),
                                            child: Slider(
                                              value: progress,
                                              min: 0,
                                              max: 1,
                                              onChanged: null,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Icon(
                                                  Icons.timer_outlined,
                                                  size: 14,
                                                  color: Colors
                                                      .grey[500]),
                                              const SizedBox(width: 4),
                                              Text(
                                                canRun
                                                    ? 'Ready!'
                                                    : '${timeLeft}s remaining',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: canRun
                                                      ? Colors
                                                          .green[700]
                                                      : Colors
                                                          .grey[600],
                                                  fontWeight: canRun
                                                      ? FontWeight
                                                          .bold
                                                      : FontWeight
                                                          .normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),

                                    const SizedBox(height: 8),

                                    // Status & action
                                    Row(
                                      children: [
                                        // Status indicator
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 10,
                                                height: 10,
                                                decoration:
                                                    BoxDecoration(
                                                  shape:
                                                      BoxShape.circle,
                                                  color: !factory
                                                          .active
                                                      ? Colors
                                                          .grey[400]
                                                      : (noInput
                                                          ? Colors
                                                              .red
                                                          : (canRun
                                                              ? Colors
                                                                  .green
                                                              : color)),
                                                ),
                                              ),
                                              const SizedBox(
                                                  width: 6),
                                              Text(
                                                !factory.active
                                                    ? 'Stopped'
                                                    : (noInput
                                                        ? 'Missing Input!'
                                                        : (canRun
                                                            ? 'Running'
                                                            : 'Processing')),
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: noInput
                                                      ? Colors
                                                          .red[600]
                                                      : Colors
                                                          .grey[600],
                                                  fontWeight: noInput
                                                      ? FontWeight
                                                          .bold
                                                      : FontWeight
                                                          .normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Manual run button
                                        if (canRun)
                                          ElevatedButton.icon(
                                            onPressed: hasInput
                                                ? () => _manualProduce(
                                                    factory)
                                                : null,
                                            icon: Icon(
                                              Icons.play_arrow,
                                              size: 18,
                                              color: hasInput
                                                  ? Colors.white
                                                  : Colors.grey,
                                            ),
                                            label: Text(
                                              hasInput
                                                  ? 'Run Now'
                                                  : 'No Input',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: hasInput
                                                    ? Colors.white
                                                    : Colors
                                                        .grey[500],
                                              ),
                                            ),
                                            style: ElevatedButton
                                                .styleFrom(
                                              backgroundColor:
                                                  hasInput
                                                      ? color
                                                      : null,
                                              disabledBackgroundColor:
                                                  Colors.grey[200],
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                horizontal: 16,
                                                vertical: 8,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(
                                                            20),
                                              ),
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