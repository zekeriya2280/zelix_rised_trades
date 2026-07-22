/// File : lib/models/city.dart
/// Version : 1.0.0
/// Status : Stable

/// Şehir veri modeli.
///
/// City:
/// - Nüfus
/// - Seviye
/// - Talep
/// - Ekonomi
/// - Bina bağlantıları
/// bilgilerini tutar.
///
/// Şehir oyunun ana ekonomik merkezidir.
///
/// Bağlantı:
///
/// Player
///    ↓
/// City
///    ↓
/// Building
///    ↓
/// Factory
///    ↓
/// Market
class City {
  City({required this.id, required this.name});

  /// Şehir kimliği.
  final String id;

  /// Şehir adı.
  String name;

  /// Şehir seviyesi.
  ///
  /// Level arttıkça:
  /// - nüfus
  /// - talep
  /// - bina kapasitesi
  /// artar.
  int level = 1;

  /// Nüfus.
  int population = 1000;

  /// Maksimum nüfus.
  int maxPopulation = 10000;

  /// Mutluluk seviyesi.
  ///
  /// 0-100
  int happiness = 50;

  /// Şehir parası.
  int economy = 100000;

  /// Bağlı bina listesi.
  final List<String> buildingIds = [];

  /// Pazar bağlantısı.
  String? marketId;

  /// Talep listesi.
  ///
  /// Key:
  /// ProductId
  ///
  /// Value:
  /// Talep miktarı
  final Map<String, int> demand = {};

  /// Aktif mi?
  bool enabled = true;

  /// Nüfus artırma.
  void increasePopulation(int amount) {
    if (amount <= 0) {
      return;
    }

    population += amount;

    if (population > maxPopulation) {
      population = maxPopulation;
    }
  }

  /// Mutluluk değişimi.
  void changeHappiness(int value) {
    happiness += value;

    if (happiness < 0) {
      happiness = 0;
    }

    if (happiness > 100) {
      happiness = 100;
    }
  }

  /// Bina ekleme.
  void addBuilding(String buildingId) {
    if (!buildingIds.contains(buildingId)) {
      buildingIds.add(buildingId);
    }
  }

  /// Şehir seviyesi artırma.
  void levelUp() {
    level++;

    maxPopulation = (maxPopulation * 1.5).round();

    economy += 50000;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,

      'name': name,

      'level': level,

      'population': population,

      'maxPopulation': maxPopulation,

      'happiness': happiness,

      'economy': economy,

      'buildingIds': buildingIds,

      'marketId': marketId,

      'demand': demand,

      'enabled': enabled,
    };
  }

  factory City.fromJson(Map<String, dynamic> json) {
    final city = City(id: json['id'], name: json['name']);

    city.level = json['level'] ?? 1;

    city.population = json['population'] ?? 1000;

    city.maxPopulation = json['maxPopulation'] ?? 10000;

    city.happiness = json['happiness'] ?? 50;

    city.economy = json['economy'] ?? 100000;

    city.marketId = json['marketId'];

    city.enabled = json['enabled'] ?? true;

    final buildings = json['buildingIds'] as List<dynamic>?;

    if (buildings != null) {
      city.buildingIds.addAll(buildings.cast<String>());
    }

    final demand = json['demand'] as Map<String, dynamic>?;

    demand?.forEach((key, value) {
      city.demand[key] = value;
    });

    return city;
  }
}
