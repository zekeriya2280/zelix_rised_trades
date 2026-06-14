import 'package:flutter/material.dart';
import 'package:zelix_rised_trades/core/engine/game_engine.dart';
import 'package:zelix_rised_trades/core/enums/resource_type.dart';
import 'package:zelix_rised_trades/core/enums/city_list.dart';
import 'package:zelix_rised_trades/core/enums/trucks_list.dart';
import 'package:zelix_rised_trades/core/models/truck.dart';
import 'package:zelix_rised_trades/core/models/warehouse.dart';
import 'package:zelix_rised_trades/screens/building_shop_screen.dart';


/// TruckScreen - Kamyonların Card + slider ile sevkiyat parametreleri.
class TruckScreen extends StatefulWidget {
  final String? preselectedFromWarehouseId;
  final String? preselectedToCityId; // City logic şimdilik UI parameter olarak taşınır.
  final ResourceType? preselectedResourceType;
  final int? preselectedAmount;

  const TruckScreen({
    super.key,
    this.preselectedFromWarehouseId,
    this.preselectedToCityId,
    this.preselectedResourceType,
    this.preselectedAmount,
  });


  @override
  State<TruckScreen> createState() => _TruckScreenState();
}

class _TruckScreenState extends State<TruckScreen> {
  final GameEngine _engine = GameEngine();

  List<Warehouse> _warehouses = [];
  List<Truck> _trucks = [];

  String? _fromWarehouseId;
  String? _toWarehouseId;

  ResourceType _resourceType = ResourceType.wood;
  int _amount = 10;

  // Truck selection should be real truck-based.
  // Placeholder for future: selected destination city.
  CityList? _selectedCity;

  int get _selectedCityDistanceLevel {
    final idx = _selectedCity?.index ?? 0;
    // Until we wire per-city properties from engine state, map enum index to 1..10.
    return (idx + 1).clamp(1, 10);
  }


  TrucksList? _selectedTruck;

  String? get _selectedTruckId =>
      _selectedTruck == null ? null : _selectedTruckEnumToEngineId(_selectedTruck!);


  int get _truckCapacity {
    if (_selectedTruckId == null) return 0;
    return _engine.getTruckCapacity(_selectedTruckId!);
  }


  int get _truckSelectedLevel {
    if (_selectedTruckId == null) return 1;
    return _engine.getTruckLevel(_selectedTruckId!);
  }





  int get _truckCapacitySafe => _truckCapacity < 1 ? 1 : _truckCapacity;

  int get _limitedAmount => _amount.clamp(1, _truckCapacitySafe);


  // Simple fee formula (UI only for now)
  double get _fee {
    if (_selectedCityDistanceLevel == 0) return 0;
    return _engine.calculateShipmentFee(
      limitedAmount: _limitedAmount,
      cityDistanceLevel: _selectedCityDistanceLevel,
    );
  }



  @override
  void initState() {
    super.initState();
    _engine.warehousesNotifier.addListener(_onDataChanged);
    _engine.stateVersion.addListener(_onDataChanged);

    _fromWarehouseId = widget.preselectedFromWarehouseId;
    _resourceType = widget.preselectedResourceType ?? ResourceType.wood;
    _amount = widget.preselectedAmount ?? 10;
    _selectedCity ??= widget.preselectedToCityId != null
        ? CityList.values.firstWhere(
            (e) => e.toString().split('.').last == widget.preselectedToCityId,
            orElse: () => CityList.values.first,
          )
        : CityList.values.isNotEmpty
            ? CityList.values.first
            : null;


    _refresh();
  }

  String _selectedTruckEnumToEngineId(TrucksList truckEnum) {
    // TrucksList sadece "truck1/truck2/truck3" isimleri.
    // Breakdown değerlerinin doğru değişmesi için enum'u engine'daki truck sırasıyla eşlemek zorundayız.
    // Ancak engine'da truck sayısı/oluş sırası farklı olabileceği için, her enum'u mevcut truck listesinde
    // deterministik bir şekilde ilk 3'e göre eşliyoruz.

    final trucks = _engine.state.trucks;
    if (trucks.isEmpty) return 't_0';

    final wantedIndex = truckEnum.index; // 0,1,2
    if (wantedIndex >= trucks.length) {
      return trucks.last.id;
    }
    return trucks[wantedIndex].id;
  }


  String? _selectedCityEnumToToWarehouseId(CityList cityEnum) {
    if (_warehouses.isEmpty) return null;
    final idx = cityEnum.index;
    final safeIdx = idx.clamp(0, _warehouses.length - 1);
    return _warehouses[safeIdx].id;
  }

  void _refresh() {
    _warehouses = _engine.getAllWarehouses();
    _trucks = _engine.state.trucks;


    if (_warehouses.isEmpty) {
      _toWarehouseId = null;
      _fromWarehouseId ??= null;
    } else {
      _fromWarehouseId ??= _warehouses.first.id;
      _toWarehouseId ??= _warehouses.length > 1 ? _warehouses.last.id : _warehouses.first.id;
    }

    _selectedTruck ??= TrucksList.values.isNotEmpty ? TrucksList.values.first : null;

    setState(() {});
  }

  void _onDataChanged() {
    if (!mounted) return;
    _refresh();
  }

  @override
  void dispose() {
    _engine.warehousesNotifier.removeListener(_onDataChanged);
    _engine.stateVersion.removeListener(_onDataChanged);
    super.dispose();
  }

  bool get _hasTruckDepot {
    // BuildingShopSystem purchasedBuildings'a buildingName ile yazıyor.
    // UI'da yazım farklılıkları (ör: çift boşluk) olabiliyor.
    final purchases = _engine.state.purchasedBuildings;
    int? count;
    for (final entry in purchases.entries) {
      final normalizedKey = entry.key.replaceAll(RegExp(r"\s+"), ' ').trim();
      if (normalizedKey == 'Truck Depot') {
        count = entry.value;
        break;
      }
    }
    return (count ?? 0) > 0;
  }


  void _createOrUseTruckAndStart() {
    if (_selectedTruckId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a truck'), backgroundColor: Colors.red),
      );
      return;
    }

    if (!_hasTruckDepot) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Truck Depot is required to start transport'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_fromWarehouseId == null || _toWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select from/to warehouse'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_fromWarehouseId == _toWarehouseId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('From and to warehouses must be different'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Eğer truck yoksa oluştur.
    final trucks = _engine.state.trucks;
    String routeId = 'route_ui_${DateTime.now().millisecondsSinceEpoch}';

    if (trucks.isEmpty) {
      _engine.createTruck(
        id: 't_${DateTime.now().millisecondsSinceEpoch}',
        routeId: routeId,
        capacity: 100,
      );
    }

    // Truck seçimi sadece UI tarafında enum ile tutuluyor.
    // Engine'a gönderilecek routeId için seçili enum'u engine id'ye çeviriyoruz.
    final selectedTruckId = _selectedTruckId;

    if (selectedTruckId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a truck'), backgroundColor: Colors.red),
      );
      return;
    }



    // Shipment: engine warehouse->warehouse yapıyor.
    // routeId bilgisi engine state’ten okunur (model oluşturma engine tarafında olur).
    final resolvedRouteId = _engine.state.trucks
        .where((t) => t.id == selectedTruckId)
        .cast<Truck?>()
        .firstOrNull
        ?.routeId ?? '';

    if (resolvedRouteId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Truck state not found (sync issue).'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }


    _engine.requestShipment(
      fromWarehouseId: _fromWarehouseId!,
      toWarehouseId: _toWarehouseId!,
      resourceType: _resourceType,
      amount: _limitedAmount,
      routeId: routeId,
      reason:
          'transport (cityDistanceLevel=$_selectedCityDistanceLevel fee=¥${_fee.toStringAsFixed(0)})',
    );




    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🚚 Shipment queued: $_amount ${_resourceType.name}  Fee: ¥${_fee.toStringAsFixed(0)}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );

    // targetTruck var/yok için UI fark etmiyor; motor transferi tick içinde tamamlıyor.
  }

  @override
  Widget build(BuildContext context) {
    final depotCount = _engine.state.purchasedBuildings['Truck Depot'] ?? 0;

    return Scaffold(
      backgroundColor: Colors.lightBlue[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart, color: Colors.black54),
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const BuildingShopScreen()),
            ),
          ),
        ],
        title: const Center(
          child: Text(
            'Trucks',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 0.8),
          ),
        ),
      ),
      body: _warehouses.isEmpty
          ? const Center(child: Text('Buy a Warehouse first'))
          : RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.local_shipping, color: Colors.teal[700]),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Truck Depot: x$depotCount',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _hasTruckDepot ? Colors.green[50] : Colors.red[50],
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _hasTruckDepot ? Colors.green : Colors.red.withValues(alpha: 0.6)),
                                ),
                                child: Text(
                                  _hasTruckDepot ? 'Ready' : 'Required',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _hasTruckDepot ? Colors.green[800] : Colors.red[800],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          DropdownButtonFormField<TrucksList>(
                            initialValue: _selectedTruck,
                            decoration: const InputDecoration(labelText: 'Select Truck'),
                            items: TrucksList.values
                                .map((tEnum) => DropdownMenuItem(
                                      value: tEnum,
                                      child: Text(tEnum.toString().split('.').last),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                _selectedTruck = v;
                                debugPrint('[Truckscreen] $_selectedTruck');
                              });
                            },

                          ),


                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: _fromWarehouseId,
                            decoration: const InputDecoration(labelText: 'From Warehouse'),
                            items: _warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                            onChanged: (v) => setState(() => _fromWarehouseId = v),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<CityList>(
                            initialValue: _selectedCity,
                            decoration: const InputDecoration(labelText: 'To City'),
                            items: CityList.values
                                .map((cEnum) => DropdownMenuItem(
                                      value: cEnum,
                                      child: Text(cEnum.toString().split('.').last),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                _selectedCity = v;
                                if (v != null) {
                                  _toWarehouseId = _selectedCityEnumToToWarehouseId(v);
                                }
                              });
                            },
                          ),


                          const SizedBox(height: 16),
                          DropdownButtonFormField<ResourceType>(
                            initialValue: _resourceType,
                            decoration: const InputDecoration(labelText: 'Resource'),
                            items: ResourceType.values
                                .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                                .toList(),
                            onChanged: (v) => setState(() => _resourceType = v ?? ResourceType.wood),
                          ),

                          const SizedBox(height: 12),
                          Slider(
                            value: _amount.toDouble(),
                            min: 1,
                            max: 100,
                            divisions: 99,
                            onChanged: (v) {
                              setState(() => _amount = v.round());
                            },
                          ),
                          Text('Amount: $_limitedAmount / cap($_truckCapacity)'),

                          const SizedBox(height: 12),
                          Text(
                            'City Distance: $_selectedCityDistanceLevel | Fee: ¥_feeFixed0',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),

                          const SizedBox(height: 6),
Text(
                            'Truck breakdown: L$_truckSelectedLevel | cap:${_selectedTruckId == null ? '-' : _engine.getTruckCapacity(_selectedTruckId!)} | spx:${_selectedTruckId == null ? '-' : _engine.getTruckEffectiveSpeedMultiplier(_selectedTruckId!).toStringAsFixed(2)} | fault:${_selectedTruckId == null ? '-' : _engine.getTruckFaultChance(_selectedTruckId!).toStringAsFixed(3)}',
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),





                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _hasTruckDepot ? _createOrUseTruckAndStart : null,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Start Transport'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text('All Trucks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  ...(_trucks.isEmpty
                      ? [
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                  'No trucks yet. Start transport once Depot is purchased.'),
                            ),
                          )
                        ]
                      : _trucks.map((t) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.local_shipping,
                                          color: Colors.teal[800]),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Truck ${t.id}',
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Text(
                                        'L${_engine.getTruckLevel(t.id)} cap:${_engine.getTruckCapacity(t.id)} spx:${_engine.getTruckEffectiveSpeedMultiplier(t.id).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),
                                  Text('RouteId: ${t.routeId}',
                                      style: const TextStyle(fontSize: 13)),
                                  const SizedBox(height: 10),
                                  const Text('Shipment Info:',
                                      style: TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'distance/fee/last shipment: (engine model currently does not persist per-truck logs)',
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList()),
                ],
              ),
          ));
  }
}


