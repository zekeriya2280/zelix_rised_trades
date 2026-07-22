import '../models/product.dart';
import '../models/factory.dart';
import '../models/warehouse.dart';
import '../models/truck.dart';

class World {
  final String playerId;

  String playerName;

  int money;

  int level;

  double inflation;

  DateTime lastTick;

  int serverVersion;

  Map<String, Product> products;

  Map<String, Factory> factories;

  Map<String, Warehouse> warehouses;

  Map<String, Truck> trucks;

  Map<String, dynamic> cities;

  Map<String, double> market;

  World({
    required this.playerId,

    required this.playerName,

    required this.money,

    this.level = 1,

    this.inflation = 0,

    DateTime? lastTick,

    this.serverVersion = 1,

    Map<String, Product>? products,

    Map<String, Factory>? factories,

    Map<String, Warehouse>? warehouses,

    Map<String, Truck>? trucks,

    Map<String, dynamic>? cities,

    Map<String, double>? market,
  }) : lastTick = lastTick ?? DateTime.now(),

       products = products ?? {},

       factories = factories ?? {},

       warehouses = warehouses ?? {},

       trucks = trucks ?? {},

       cities = cities ?? {},

       market = market ?? {};

  // =========================
  // TICK UPDATE
  // =========================

  void updateTick() {
    lastTick = DateTime.now();
  }

  bool spendMoney(int amount) {
    if (money < amount) {
      return false;
    }

    money -= amount;

    return true;
  }

  void addMoney(int amount) {
    money += amount;
  }

  // =========================
  // JSON
  // =========================

  Map<String, dynamic> toJson() {
    return {
      "playerId": playerId,

      "playerName": playerName,

      "money": money,

      "level": level,

      "inflation": inflation,

      "lastTick": lastTick.toIso8601String(),

      "serverVersion": serverVersion,

      "products": products.map((key, value) => MapEntry(key, value.toJson())),

      "factories": factories.map((key, value) => MapEntry(key, value.toJson())),

      "warehouses": warehouses.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),

      "trucks": trucks.map((key, value) => MapEntry(key, value.toJson())),

      "cities": cities,

      "market": market,
    };
  }

  factory World.fromJson(Map<String, dynamic> json) {
    return World(
      playerId: json["playerId"],

      playerName: json["playerName"] ?? "Player",

      money: json["money"] ?? 0,

      level: json["level"] ?? 1,

      inflation: (json["inflation"] ?? 0).toDouble(),

      lastTick: DateTime.parse(json["lastTick"]),

      serverVersion: json["serverVersion"] ?? 1,

      products: (json["products"] ?? {}).map<String, Product>(
        (key, value) => MapEntry(key, Product.fromJson(value)),
      ),

      factories: (json["factories"] ?? {}).map<String, Factory>(
        (key, value) => MapEntry(key, Factory.fromJson(value)),
      ),

      warehouses: (json["warehouses"] ?? {}).map<String, Warehouse>(
        (key, value) => MapEntry(key, Warehouse.fromJson(value)),
      ),

      trucks: (json["trucks"] ?? {}).map<String, Truck>(
        (key, value) => MapEntry(key, Truck.fromJson(value)),
      ),

      cities: json["cities"] ?? {},

      market: Map<String, double>.from(json["market"] ?? {}),
    );
  }
}
