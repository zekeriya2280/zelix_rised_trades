import 'package:flutter/material.dart';

import '../core/enums/resource_type.dart';
import '../core/models/warehouse.dart';

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
  late String activeActionLabel;
  late String routeDescription;

  final sourceOptions = ['Warehouse'];
  final productOptions = ['Wood', 'Lumber', 'Furniture'];
  final destinationOptions = ['Lumber Mill', 'Furniture Factory', 'Tokyo'];

  @override
  void initState() {
    super.initState();
    selectedSource = widget.selectedSource;
    selectedProduct = widget.selectedProduct;
    selectedDestination = widget.selectedDestination;
    activeActionLabel = widget.activeActionLabel;
    routeDescription = widget.routeDescription;
  }

  WarehouseAction getSelectedAction() {
    if (selectedProduct == 'Wood' && selectedDestination == 'Lumber Mill') {
      return WarehouseAction.autoLumber;
    }
    if (selectedProduct == 'Lumber' && selectedDestination == 'Furniture Factory') {
      return WarehouseAction.autoFurniture;
    }
    if (selectedProduct == 'Furniture' && selectedDestination == 'Tokyo') {
      return WarehouseAction.autoSell;
    }
    return WarehouseAction.none;
  }

  bool get hasValidSelection => getSelectedAction() != WarehouseAction.none;

  String get actionTitle {
    switch (activeActionLabel) {
      case 'autoLumber':
        return 'Wood to Lumber Mill';
      case 'autoFurniture':
        return 'Lumber to Furniture Factory';
      case 'autoSell':
        return 'Furniture to City Sale';
      default:
        return 'No active route';
    }
  }

  int get activeTimer {
    switch (activeActionLabel) {
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

  Color get activeColor {
    switch (activeActionLabel) {
      case 'autoLumber':
        return Colors.orange.shade300;
      case 'autoFurniture':
        return Colors.blue.shade300;
      case 'autoSell':
        return Colors.green.shade300;
      default:
        return Colors.grey.shade500;
    }
  }

  Widget actionProgressCard() {
    final enabled = activeActionLabel != 'none';
    final baseColor = enabled ? activeColor : Colors.grey;
    final label = enabled ? '${productionPercent()}% complete' : 'Waiting for route';

    return Card(
      color: baseColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Active Warehouse Route',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              actionTitle,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: enabled ? baseColor.withAlpha((0.95 * 255).round()) : Colors.white54,
                inactiveTrackColor: enabled ? baseColor.withAlpha((0.4 * 255).round()) : Colors.white24,
                thumbColor: enabled ? baseColor.withAlpha((0.9 * 255).round()) : Colors.white38,
                overlayColor: enabled ? baseColor.withAlpha((0.25 * 255).round()) : Colors.white30,
              ),
              child: Slider(
                value: enabled ? activeTimer.toDouble() : 0.0,
                min: 0,
                max: widget.productionInterval.toDouble(),
                divisions: widget.productionInterval,
                label: label,
                onChanged: null,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  double productionPercent() {
    if (widget.productionInterval == 0) return 0;
    return (activeTimer / widget.productionInterval * 100).clamp(0, 100).toDouble();
  }

  Widget buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      initialValue: value,
      items: items.map((item) {
        return DropdownMenuItem(value: item, child: Text(item));
      }).toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedAction = getSelectedAction();
    final canStart = hasValidSelection;
    final targetDescription = canStart ? '$selectedProduct → $selectedDestination' : 'Please choose a valid product and destination';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Warehouse Control'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.brown[200],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Warehouse Status',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text('Wood: ${widget.warehouse.getResource('Wood')}', style: const TextStyle(color: Colors.white)),
                    Text('Lumber: ${widget.warehouse.getResource('Lumber')}', style: const TextStyle(color: Colors.white)),
                    Text('Furniture: ${widget.warehouse.getResource('Furniture')}', style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 12),
                    Text('Active route: $routeDescription', style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            buildDropdownField(
              label: 'From',
              value: selectedSource,
              items: sourceOptions,
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  selectedSource = value;
                });
                widget.onSourceChanged(value);
              },
            ),
            const SizedBox(height: 12),
            buildDropdownField(
              label: 'Product',
              value: selectedProduct,
              items: productOptions,
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  selectedProduct = value;
                });
                widget.onProductChanged(value);
              },
            ),
            const SizedBox(height: 12),
            buildDropdownField(
              label: 'To',
              value: selectedDestination,
              items: destinationOptions,
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  selectedDestination = value;
                });
                widget.onDestinationChanged(value);
              },
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Route Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(targetDescription),
                    const SizedBox(height: 8),
                    Text('Lumber Mills: ${widget.lumberMills}, Furniture Factories: ${widget.furnitureFactories}'),
                    if (!canStart)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Use Wood → Lumber Mill, Lumber → Furniture Factory or Furniture → Tokyo to start a valid route.', style: TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: canStart ? () {
                activeActionLabel = selectedAction.name;
                routeDescription = '$selectedProduct from $selectedSource → $selectedDestination';
                widget.onStartRoute();
                setState(() {});
              } : null,
              child: const Text('Start Warehouse Route'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: activeActionLabel != 'none' ? () {
                activeActionLabel = 'none';
                routeDescription = 'No active warehouse route';
                widget.onStopRoute();
                setState(() {});
              } : null,
              child: const Text('Stop Warehouse Route'),
            ),
            const SizedBox(height: 16),
            actionProgressCard(),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 8),
                    Text('Use the warehouse route selection to decide what product moves to which factory or city. The main menu sliders will now reflect the active warehouse automation.'),
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

enum WarehouseAction {
  none,
  autoLumber,
  autoFurniture,
  autoSell,
}

extension WarehouseResourceExtension on Warehouse {
  int getResource(String name) {
    switch (name) {
      case 'Wood':
        return get(ResourceType.wood);
      case 'Lumber':
        return get(ResourceType.lumber);
      case 'Furniture':
        return get(ResourceType.furniture);
      default:
        return 0;
    }
  }
}
