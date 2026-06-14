import '../enums/resource_type.dart';
import '../models/city.dart';
import '../models/factory.dart';
import '../models/player.dart';
import '../models/route_model.dart';
import '../models/truck.dart';
import '../models/warehouse.dart';

/// Merkezi oyun durumu.
/// Tüm veriler burada saklanır, sistemler bu state üzerinde çalışır.
/// UI sadece bu state'i okur (ValueNotifier ile).
class GameState {
  Player player;
  final List<Factory> factories;
  final List<Warehouse> warehouses;
  final List<Truck> trucks;
  final List<RouteModel> routes;
  final List<City> cities;

  /// Satın alınan building'lerin sayısı (örn: {"Forest": 2, "Lumber Mill": 1})
  /// Kalıcıdır, UI rebuild'lerde kaybolmaz.
  final Map<String, int> purchasedBuildings;

  GameState({
    required this.player,
    List<Factory>? factories,
    List<Warehouse>? warehouses,
    List<Truck>? trucks,
    List<RouteModel>? routes,
    List<City>? cities,
    Map<String, int>? purchasedBuildings,
  })  : factories = factories ?? [],
        warehouses = warehouses ?? [],
        trucks = trucks ?? [],
        routes = routes ?? [],
        cities = cities ?? [],
        purchasedBuildings = purchasedBuildings ?? {};

  /// Warehouse ID'sine göre warehouse bul
  Warehouse? getWarehouse(String id) {
    try {
      return warehouses.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Factory ID'sine göre factory bul
  Factory? getFactory(String id) {
    try {
      return factories.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Factory tipine göre factory'leri filtrele
  List<Factory> getFactoriesByType(dynamic type) {
    return factories.where((f) => f.type == type).toList();
  }

  /// Aktif factory sayısı
  int get activeFactoryCount => factories.where((f) => f.active).length;

  /// Toplam warehouse kapasitesi
  int get totalWarehouseCapacity =>
      warehouses.fold(0, (sum, w) => sum + w.capacity);

  /// Toplam kullanılan kapasite
  int get totalUsedCapacity =>
      warehouses.fold(0, (sum, w) => sum + w.usedCapacity);

  /// Belirtilen kaynağın tüm warehouse'lardaki toplam miktarı
  int getTotalResource(ResourceType type) {
    return warehouses.fold<int>(
      0,
      (sum, w) => sum + w.get(type),
    );
  }

  /// Player'a para ekle
  void addMoney(int amount) {
    player.money = (player.money + amount).clamp(0, 999999999);
  }

  /// Player'dan para düş
  bool deductMoney(int amount) {
    if (player.money < amount) return false;
    player.money = (player.money - amount).clamp(0, 999999999);
    return true;
  }

  /// Factory ekle
  void addFactory(Factory factory) {
    factories.add(factory);
  }

  /// Factory sil
  void removeFactory(String id) {
    factories.removeWhere((f) => f.id == id);
  }

  /// Warehouse ekle
  void addWarehouse(Warehouse warehouse) {
    warehouses.add(warehouse);
  }

  /// Warehouse sil
  void removeWarehouse(String id) {
    warehouses.removeWhere((w) => w.id == id);
  }

  /// Truck ekle
  void addTruck(Truck truck) {
    trucks.add(truck);
  }

  /// Truck sil
  void removeTruck(String id) {
    trucks.removeWhere((t) => t.id == id);
  }

  /// Route ekle
  void addRoute(RouteModel route) {
    routes.add(route);
  }

  /// Route sil
  void removeRoute(String id) {
    routes.removeWhere((r) => r.id == id);
  }

  /// State'in tam kopyasını oluştur (immutable snapshot için)
  GameState copy() {
    return GameState(
      player: Player(nickname: player.nickname, money: player.money),
      factories: List.from(factories),
      warehouses: List.from(warehouses),
      trucks: List.from(trucks),
      routes: List.from(routes),
      cities: List.from(cities),
    );
  }
}