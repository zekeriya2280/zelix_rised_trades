import 'package:flutter/material.dart';
import '../core/enums/resource_type.dart';
import '../core/models/warehouse.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class WarehouseScreen extends StatefulWidget {
  final Warehouse warehouse;
  final int lumberMills;
  final int furnitureFactories;
  final String activeActionLabel;
  final int lumberProductionTimer;
  final int furnitureProductionTimer;
  final int sellTimer;
  final int productionInterval;

  final String selectedSource;
  final String selectedProduct;
  final String selectedDestination;
  final String routeDescription;

  final ValueChanged<String> onSourceChanged;
  final ValueChanged<String> onProductChanged;
  final ValueChanged<String> onDestinationChanged;

  final VoidCallback onStartRoute;
  final VoidCallback onStopRoute;

  const WarehouseScreen({
    super.key,
    required this.warehouse,
    required this.lumberMills,
    required this.furnitureFactories,
    required this.activeActionLabel,
    required this.lumberProductionTimer,
    required this.furnitureProductionTimer,
    required this.sellTimer,
    required this.productionInterval,
    required this.selectedSource,
    required this.selectedProduct,
    required this.selectedDestination,
    required this.routeDescription,
    required this.onSourceChanged,
    required this.onProductChanged,
    required this.onDestinationChanged,
    required this.onStartRoute,
    required this.onStopRoute,
  });

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  late String selectedSource;
  late String selectedProduct;
  late String selectedDestination;

  @override
  void initState() {
    super.initState();

    selectedSource = widget.selectedSource;
    selectedProduct = widget.selectedProduct;
    selectedDestination = widget.selectedDestination;
  }

  @override
  void didUpdateWidget(covariant WarehouseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    selectedSource = widget.selectedSource;
    selectedProduct = widget.selectedProduct;
    selectedDestination = widget.selectedDestination;
  }

  int get activeTimer {
    switch (widget.activeActionLabel) {
      case 'autoLumber':
        return widget.lumberProductionTimer;

      case 'autoFurniture':
        return widget.furnitureProductionTimer;

      case 'autoSell':
        return widget.sellTimer;

      default:
        return 0;
    }
  }

  bool get hasValidSelection {
    return (selectedProduct == 'Wood' &&
            selectedDestination == 'Lumber Mill') ||
        (selectedProduct == 'Lumber' &&
            selectedDestination == 'Furniture Factory') ||
        (selectedProduct == 'Furniture' &&
            selectedDestination == 'Tokyo');
  }

  String get actionTitle {
    switch (widget.activeActionLabel) {
      case 'autoLumber':
        return 'Wood → Lumber Mill';

      case 'autoFurniture':
        return 'Lumber → Furniture Factory';

      case 'autoSell':
        return 'Furniture → Tokyo';

      default:
        return 'No Active Route';
    }
  }

  double get progress {
    if (widget.productionInterval <= 0) return 0;

    return activeTimer
        .toDouble()
        .clamp(0, widget.productionInterval.toDouble());
  }

  Widget stockTile(String title, int amount) {
    return Card(
      color: Colors.brown.shade200,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '$amount',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      items: items
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(e),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        onChanged(v);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Warehouse'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              color: Colors.brown,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Warehouse Stock',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    stockTile(
                      'Wood',
                      widget.warehouse.get(ResourceType.wood),
                    ),
                    stockTile(
                      'Lumber',
                      widget.warehouse.get(ResourceType.lumber),
                    ),
                    stockTile(
                      'Furniture',
                      widget.warehouse.get(ResourceType.furniture),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            dropdown(
              label: 'Source',
              value: selectedSource,
              items: const [
                'Warehouse',
              ],
              onChanged: (value) {
                setState(() {
                  selectedSource = value;
                });

                widget.onSourceChanged(value);
              },
            ),

            const SizedBox(height: 12),

            dropdown(
              label: 'Product',
              value: selectedProduct,
              items: const [
                'Wood',
                'Lumber',
                'Furniture',
              ],
              onChanged: (value) {
                setState(() {
                  selectedProduct = value;
                });

                widget.onProductChanged(value);
              },
            ),

            const SizedBox(height: 12),

            dropdown(
              label: 'Destination',
              value: selectedDestination,
              items: const [
                'Lumber Mill',
                'Furniture Factory',
                'Tokyo',
              ],
              onChanged: (value) {
                setState(() {
                  selectedDestination = value;
                });

                widget.onDestinationChanged(value);
              },
            ),

            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      widget.routeDescription,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    ElevatedButton(
                      onPressed: hasValidSelection
                          ? widget.onStartRoute
                          : null,
                      child: const Text(
                        'Start Route',
                      ),
                    ),

                    const SizedBox(height: 8),

                    OutlinedButton(
                      onPressed:
                          widget.activeActionLabel != 'none'
                              ? widget.onStopRoute
                              : null,
                      child: const Text(
                        'Stop Route',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Card(
              color: Colors.blueGrey,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      actionTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),

                    Slider(
                      value: progress,
                      min: 0,
                      max: widget.productionInterval.toDouble(),
                      onChanged: null,
                    ),

                    Text(
                      '$activeTimer / ${widget.productionInterval}',
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Lumber Mills: ${widget.lumberMills}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Furniture Factories: ${widget.furnitureFactories}',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

