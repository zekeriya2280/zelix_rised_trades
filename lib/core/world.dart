/// File : lib/core/world.dart
/// Version : 1.2.0
/// Status : Stable

class World {
  //========================
  // Time
  //========================

  DateTime gameTime = DateTime(2026, 1, 1, 8);

  double gameSpeed = 1.0;

  bool paused = false;

  //========================
  // Economy
  //========================

  int money = 100000;

  //========================
  // Entities
  //========================

  final Map<String, dynamic> players = {};

  final Map<String, dynamic> cities = {};

  final Map<String, dynamic> factories = {};

  final Map<String, dynamic> warehouses = {};

  final Map<String, dynamic> trucks = {};

  //========================
  // Time
  //========================

  void advanceTime(Duration delta) {
    if (paused) return;

    gameTime = gameTime.add(
      Duration(microseconds: (delta.inMicroseconds * gameSpeed).round()),
    );
  }

  //========================
  // Economy
  //========================

  void addMoney(int amount) {
    money += amount;
  }

  bool spendMoney(int amount) {
    if (money < amount) {
      return false;
    }

    money -= amount;

    return true;
  }

  //========================
  // Game
  //========================

  void pause() {
    paused = true;
  }

  void resume() {
    paused = false;
  }

  void setGameSpeed(double speed) {
    if (speed <= 0) return;

    gameSpeed = speed;
  }

  //========================
  // Save
  //========================

  Map<String, dynamic> toJson() {
    return {
      'gameTime': gameTime.toIso8601String(),
      'gameSpeed': gameSpeed,
      'paused': paused,
      'money': money,

      // Şimdilik boş.
      // Model sınıfları yazıldığında doldurulacak.
      'players': players,
      'cities': cities,
      'factories': factories,
      'warehouses': warehouses,
      'trucks': trucks,
    };
  }

  void loadFromJson(Map<String, dynamic> json) {
    gameTime = DateTime.parse(json['gameTime']);

    gameSpeed = (json['gameSpeed'] as num).toDouble();

    paused = json['paused'];

    money = json['money'];

    players
      ..clear()
      ..addAll(json['players']);

    cities
      ..clear()
      ..addAll(json['cities']);

    factories
      ..clear()
      ..addAll(json['factories']);

    warehouses
      ..clear()
      ..addAll(json['warehouses']);

    trucks
      ..clear()
      ..addAll(json['trucks']);
  }
}
