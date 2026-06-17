import 'package:flutter/material.dart';
import 'package:zelix_rised_trades/core/engine/game_engine.dart';
import 'package:zelix_rised_trades/core/enums/city_list.dart';
import 'package:zelix_rised_trades/core/enums/resource_type.dart';
import 'package:zelix_rised_trades/core/models/truck.dart';
import 'package:zelix_rised_trades/core/models/warehouse.dart';

/// Transport Screen - Sevkiyat ayarları
/// TruckManagementScreen'den seçili truckId ile gelinir.
/// Start Transport'a basınca truck'ın statusü engine tarafından güncellenir.
class TransportScreen extends StatefulWidget {
  /// Entry point can pass any truck id, but the screen will
  /// always allow selecting among all owned trucks.
  final String truckId;

  const TransportScreen({super.key, required this.truckId});


  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> {
  final GameEngine _engine = GameEngine();

  List<Warehouse> _warehouses = [];
  List<Truck> _trucks = [];

  String? _selectedTruckId;

  String? _fromWarehouseId;

  String? _toWarehouseId;
  CityList? _selectedCity;
  ResourceType _resourceType = ResourceType.wood;
  int _amount = 1;

  Truck? get _truck {
    if (_selectedTruckId == null) return null;
    try {
      return _trucks.firstWhere((t) => t.id == _selectedTruckId);
    } catch (_) {
      return null;
    }
  }


  int get _truckCapacity => _truck?.effectiveCapacity ?? 100;
  int get _limitedAmount => _amount.clamp(1, _truckCapacity);

  int get _selectedCityDistanceLevel {
    final idx = _selectedCity?.index ?? 0;
    return (idx + 1).clamp(1, 10);
  }

  double get _fee {
    if (_selectedCityDistanceLevel == 0) return 0;
    return _engine.calculateShipmentFee(
      limitedAmount: _limitedAmount,
      cityDistanceLevel: _selectedCityDistanceLevel,
    );
  }

  bool get _hasTruckDepot {
    final purchases = _engine.state.purchasedBuildings;
    for (final entry in purchases.entries) {
      if (entry.key.replaceAll(RegExp(r"\s+"), ' ').trim() == 'Truck Depot') {
        return (entry.value) > 0;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _engine.stateVersion.addListener(_onDataChanged);
    _engine.warehousesNotifier.addListener(_onDataChanged);
    _refresh();
  }

  @override
  void dispose() {
    _engine.stateVersion.removeListener(_onDataChanged);
    _engine.warehousesNotifier.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (!mounted) return;
    _refresh();
  }

  void _refresh() {
    _warehouses = _engine.getAllWarehouses();
    _trucks = _engine.state.trucks;

    // ensure selected truck is valid
    if (_trucks.isEmpty) {
      _selectedTruckId = null;
    } else {
      final incomingExists = _trucks.any((t) => t.id == widget.truckId);
      if (_selectedTruckId == null) {
        _selectedTruckId = incomingExists ? widget.truckId : _trucks.first.id;
      } else {
        // if trucks changed (sold/reset), keep selection valid
        if (!_trucks.any((t) => t.id == _selectedTruckId)) {
          _selectedTruckId = incomingExists ? widget.truckId : _trucks.first.id;
        }
      }
    }

    if (_warehouses.isNotEmpty) {
      _fromWarehouseId ??= _warehouses.first.id;
      _toWarehouseId ??= _warehouses.length > 1
            ? _warehouses.last.id
            : _warehouses.first.id;

      // If user accidentally selected same from/to, auto-fix to different when possible
      if (_warehouses.length > 1 &&
          _fromWarehouseId != null &&
          _toWarehouseId != null &&
          _fromWarehouseId == _toWarehouseId) {
        _toWarehouseId = _warehouses.firstWhere((w) => w.id != _fromWarehouseId!).id;
      }
    }

    _amount = _amount.clamp(1, _truckCapacity);
    setState(() {});
  }



  void _startTransport() {
    if (!_hasTruckDepot) {
      _showSnack('Truck Depot required!', Colors.red);
      return;
    }
    if (_fromWarehouseId == null || _toWarehouseId == null) {
      _showSnack('Select from/to warehouse', Colors.red);
      return;
    }
    if (_fromWarehouseId == _toWarehouseId) {
      _showSnack('From and To must be different', Colors.orange);
      return;
    }

    // Engine üzerinden sevkiyatı başlat
    // assignTruckRoute → assignedRouteId + status:loading yapar
    // requestShipment → pendingShipments'a ekler, tick'te işlenir
    final routeId = 'route_${DateTime.now().millisecondsSinceEpoch}';
    final selectedId = _selectedTruckId;
    if (selectedId == null) {
      _showSnack('No truck selected', Colors.red);
      return;
    }
    _engine.assignTruckRoute(selectedId, routeId);


    _engine.requestShipment(
      fromWarehouseId: _fromWarehouseId!,
      toWarehouseId: _toWarehouseId!,
      resourceType: _resourceType,
      amount: _limitedAmount,
      routeId: routeId,
      reason:
          'transport (city=$_selectedCityDistanceLevel fee=¥${_fee.toStringAsFixed(0)})',
    );

    _showSnack('🚚 ${_truck?.name ?? "Truck"} en route!', Colors.green);

    // Bir süre sonra geri dön
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

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

  String? _selectedCityEnumToWarehouseId(CityList cityEnum) {
    if (_warehouses.isEmpty) return null;
    final idx = cityEnum.index.clamp(0, _warehouses.length - 1);
    return _warehouses[idx].id;
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

  @override
  Widget build(BuildContext context) {
    final truck = _truck;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(truck != null ? '🚚 ${truck.name}' : 'Transport'),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
      ),
      body: truck == null
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    _trucks.isEmpty ? 'No trucks purchased yet' : 'Truck not found',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            )
          : ListView(

              padding: const EdgeInsets.all(16),
              children: [
                // ===== TRUCK ÖZET =====
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                        color: Colors.teal.withValues(alpha: 0.5)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.local_shipping,
                              color: Colors.teal, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(truck.name,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              Text(
                                  'Lv.${truck.level} | Cap:${truck.effectiveCapacity} | ${truck.status.name}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600])),
                            ],
                          ),
                        ),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(truck.status)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _statusColor(truck.status)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            truck.status.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _statusColor(truck.status),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ===== TRUCK SELECTOR =====
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.local_shipping,
                                size: 20, color: Colors.teal[700]),
                            const SizedBox(width: 8),
                            const Text('Select Truck',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedTruckId,
                          decoration: const InputDecoration(
                            labelText: 'Truck',
                            prefixIcon: Icon(Icons.directions_car),
                            border: OutlineInputBorder(),
                          ),
                          items: _trucks
                              .map((t) => DropdownMenuItem<String>(
                                    value: t.id,
                                    child: Text('${t.name} (Lv.${t.level})'),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedTruckId = v),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ===== SEVKİYAT AYARLARI =====
                Card(

                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.settings,
                                size: 20, color: Colors.teal[700]),
                            const SizedBox(width: 8),
                            const Text('Transport Settings',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // From Warehouse
                        DropdownButtonFormField<String>(
                          initialValue: _fromWarehouseId,
                          decoration: const InputDecoration(
                            labelText: 'From Warehouse',
                            prefixIcon: Icon(Icons.exit_to_app),
                            border: OutlineInputBorder(),
                          ),
                          items: _warehouses
                              .map((w) => DropdownMenuItem(
                                  value: w.id, child: Text(w.name)))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _fromWarehouseId = v;
                              // keep from/to different when possible
                              if (_warehouses.length > 1 &&
                                  _fromWarehouseId != null &&
                                  _toWarehouseId != null &&
                                  _fromWarehouseId == _toWarehouseId) {
                                _toWarehouseId = _warehouses
                                        .firstWhere((w) => w.id != _fromWarehouseId)
                                        .id;
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        // To City
                        DropdownButtonFormField<CityList>(
                          initialValue: _selectedCity,
                          decoration: const InputDecoration(
                            labelText: 'To City',
                            prefixIcon: Icon(Icons.location_city),
                            border: OutlineInputBorder(),
                          ),
                          items: CityList.values
                              .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                        c.toString().split('.').last),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _selectedCity = v;
                              if (v != null) {
                                final fromId = _fromWarehouseId;
                                var targetId = _selectedCityEnumToWarehouseId(v);

                                // Guarantee from != to when possible
                                if (targetId != null &&
                                    fromId != null &&
                                    _warehouses.length > 1 &&
                                    targetId == fromId) {
                                  targetId = _warehouses
                                      .firstWhere((w) => w.id != fromId)
                                      .id;
                                }

                                _toWarehouseId = targetId;
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        // Resource
                        DropdownButtonFormField<ResourceType>(
                          initialValue: _resourceType,
                          decoration: const InputDecoration(
                            labelText: 'Resource',
                            prefixIcon: Icon(Icons.inventory),
                            border: OutlineInputBorder(),
                          ),
                          items: ResourceType.values
                              .map((r) => DropdownMenuItem(
                                  value: r, child: Text(r.name)))
                              .toList(),
                          onChanged: (v) => setState(
                              () => _resourceType = v ?? ResourceType.wood),
                        ),
                        const SizedBox(height: 16),

                        // Amount
                        Row(
                          children: [
                            const Text('Amount:',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Slider(
                                value: _limitedAmount.toDouble(),
                                min: 1,
                                max: _truckCapacity.toDouble(),
                                divisions:
                                    (_truckCapacity - 1).clamp(1, 999),
                                onChanged: (v) =>
                                    setState(() => _amount = v.round()),
                              ),
                            ),
                            SizedBox(
                              width: 60,
                              child: Text(
                                '$_limitedAmount',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Capacity: $_truckCapacity | Fee: ¥${_fee.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ===== START TRANSPORT BUTONU =====
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _hasTruckDepot ? _startTransport : null,
                    icon: const Icon(Icons.play_arrow, size: 28),
                    label: const Text('START TRANSPORT',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),

                if (!_hasTruckDepot)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '⚠️ Truck Depot required - buy from Building Shop',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12, color: Colors.red[400]),
                    ),
                  ),
              ],
            ),
    );
  }
}