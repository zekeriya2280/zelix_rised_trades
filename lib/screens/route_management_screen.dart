import 'package:flutter/material.dart';
import 'package:zelix_rised_trades/core/engine/game_engine.dart';
import 'package:zelix_rised_trades/core/models/truck.dart';
import 'package:zelix_rised_trades/core/models/route_model.dart';

/// Route Management Screen - Transport başlamış kamyonları gösterir
/// Status: loading, moving, unloading olan truck'ları listeler
class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  final GameEngine _engine = GameEngine();

  List<Truck> _activeTrucks = [];
  List<Truck> _idleTrucks = [];
  List<Truck> _allTrucks = [];
  Map<String, RouteModel> _routeMap = {};
  bool _showOnlyActive = true;

  @override
  void initState() {
    super.initState();
    _engine.stateVersion.addListener(_onDataChanged);
    _refresh();
  }

  @override
  void dispose() {
    _engine.stateVersion.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (!mounted) return;
    _refresh();
  }

  void _refresh() {
    // Tüm truck'ları al
    final allTrucks = _engine.state.trucks;
    _allTrucks = List.from(allTrucks);

    // Transport başlamış kamyonları filtrele (loading, moving, unloading)
    _activeTrucks = allTrucks.where((truck) {
      return truck.status == TruckStatus.loading ||
          truck.status == TruckStatus.moving ||
          truck.status == TruckStatus.unloading;
    }).toList();

    // Idle ve route atanmış olan truck'ları da al (yakın zamanda transport yapmış olabilir)
    _idleTrucks = allTrucks.where((truck) {
      return truck.status == TruckStatus.idle && 
             (truck.assignedRouteId != null || truck.mileage > 0);
    }).toList();

    // Rota bilgilerini map'e al
    _routeMap = {};
    for (final route in _engine.state.routes) {
      _routeMap[route.id] = route;
    }

    setState(() {});
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
        return Icons.local_shipping;
      case TruckStatus.unloading:
        return Icons.upload;
      case TruckStatus.broken:
        return Icons.error;
      case TruckStatus.maintenance:
        return Icons.build;
    }
  }

  String _statusDescription(TruckStatus status) {
    switch (status) {
      case TruckStatus.loading:
        return 'Yükleniyor';
      case TruckStatus.moving:
        return 'Yolda';
      case TruckStatus.unloading:
        return 'Boşaltılıyor';
      default:
        return status.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayTrucks = _showOnlyActive ? _activeTrucks : _allTrucks;
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Kamyon Takip (${displayTrucks.length})'),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Toggle filter button
          IconButton(
            icon: Icon(_showOnlyActive ? Icons.filter_alt : Icons.filter_alt_off),
            tooltip: _showOnlyActive ? 'Tümünü Göster' : 'Sadece Aktif',
            onPressed: () {
              setState(() {
                _showOnlyActive = !_showOnlyActive;
              });
            },
          ),
        ],
      ),
      body: displayTrucks.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                // Status summary
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.all(16).copyWith(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatusCount('Aktif', _activeTrucks.length, Colors.green),
                      Container(width: 1, height: 30, color: Colors.grey[300]),
                      _buildStatusCount('Idle', _idleTrucks.length, Colors.grey),
                      Container(width: 1, height: 30, color: Colors.grey[300]),
                      _buildStatusCount('Toplam', _allTrucks.length, Colors.teal),
                    ],
                  ),
                ),
                // Trucks list
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      _refresh();
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: displayTrucks.length,
                      itemBuilder: (context, index) {
                        final truck = displayTrucks[index];
                        return _buildTruckTransportCard(truck);
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatusCount(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildTruckTransportCard(Truck truck) {
    final route = truck.assignedRouteId != null
        ? _routeMap[truck.assignedRouteId]
        : null;

    final statusColor = _statusColor(truck.status);
    final statusIconData = _statusIcon(truck.status);
    final isActive = truck.status != TruckStatus.idle && 
                     truck.status != TruckStatus.maintenance;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isActive ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: statusColor.withValues(alpha: 0.3),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              statusColor.withValues(alpha: isActive ? 0.08 : 0.03),
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
              // Üst kısım: Truck icon + bilgi + status badge
              Row(
                children: [
                  // Truck Icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.local_shipping,
                      color: statusColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Truck bilgisi
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          truck.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Lv.${truck.level} | Kapasite: ${truck.effectiveCapacity}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Kilometre: ${truck.mileage} km',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusIconData,
                          size: 16,
                          color: statusColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _statusDescription(truck.status).toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Rota bilgileri
              if (route != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.route,
                      size: 18,
                      color: Colors.teal[700],
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Rota Bilgileri',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Başlangıç -> Varış
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.teal.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Başlangıç
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Başlangıç',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              route.source,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Arrow
                      Icon(
                        Icons.arrow_forward,
                        color: Colors.teal[700],
                        size: 24,
                      ),
                      const SizedBox(width: 8),

                      // Varış
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Varış',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              route.destination,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Rota atanmamış
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Rota bilgisi mevcut değil',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Truck detayları
              Row(
                children: [
                  _buildDetailChip(
                    Icons.speed,
                    'Hız',
                    truck.effectiveSpeed.toStringAsFixed(1),
                    Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _buildDetailChip(
                    Icons.favorite,
                    'Dayanıklılık',
                    '${truck.durability}/100',
                    truck.durability > 70
                        ? Colors.green
                        : (truck.durability > 40 ? Colors.orange : Colors.red),
                  ),
                  const SizedBox(width: 8),
                  _buildDetailChip(
                    Icons.warning_amber,
                    'Arıza',
                    '${(truck.failureChance * 100).toInt()}%',
                    Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailChip(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            _showOnlyActive ? 'Aktif Transport Yok' : 'Kamyon Yok',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _showOnlyActive 
                ? 'Şu anda yolda olan kamyon bulunmuyor\nTüm kamyonları görmek için filtre butonuna tıklayın'
                : 'Hiç kamyon satın almadınız',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_showOnlyActive && _allTrucks.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _showOnlyActive = false;
                });
              },
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Tüm Kamyonları Göster'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Ana Ekrana Dön'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
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

