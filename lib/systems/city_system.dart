// lib/systems/city_system.dart
// 89. Adım
//
// City System
//
// Görev:
// - Şehir yönetimi
// - Nüfus
// - Seviye
// - Ürün talebi
// - Tüketim sistemi altyapısı
//
// CitySystem diğer sistemlerden World üzerinden veri alır.
// Game loop içinde sistemlerin sıralı update edilmesi,
// oyun state'inin tutarlı ilerlemesini sağlar.
// :contentReference[oaicite:0]{index=0}

import '../core/world.dart';

class CitySystem {
  void update(World world, Duration delta) {
    updateCities(world, delta);
  }

  // =========================
  // UPDATE CITIES
  // =========================

  void updateCities(World world, Duration delta) {
    // İleride:
    //
    // - nüfus artışı
    // - şehir seviyesi
    // - otomatik tüketim
    // - talep değişimi
    //
  }

  // =========================
  // CITY LEVEL UP
  // =========================

  bool levelUp({
    required dynamic city,

    required int cost,

    required World world,
  }) {
    if (!world.spendMoney(cost)) {
      return false;
    }

    city.level++;

    return true;
  }

  // =========================
  // DEMAND
  // =========================

  double getDemandMultiplier(dynamic city) {
    // Nüfus ve şehir seviyesine göre
    // ürün talebi hesaplanacak.

    return 1.0;
  }

  // =========================
  // CONSUMPTION
  // =========================

  int calculateConsumption({required int population, required int baseDemand}) {
    return population * baseDemand;
  }
}
