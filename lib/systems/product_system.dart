// lib/systems/product_system.dart
// 88. Adım
//
// Product System
//
// Görev:
// - Ürün kayıtları
// - Ürün bilgisi yönetimi
// - Temel fiyat kontrolü
// - Üretim zinciri bağlantısı
// - Talep sistemi altyapısı
//
// Sistemlerin ortak World üzerinden güncellenmesi,
// oyun mantığının modüler tutulmasını sağlar.
// ([developer.apple.com](https://developer.apple.com/documentation/gameplaykit/gkcomponentsystem))

import '../core/world.dart';
import '../models/product.dart';

class ProductSystem {
  void update(World world, Duration delta) {
    _updateProducts(world);
  }

  // =========================
  // REGISTER PRODUCT
  // =========================

  void registerProduct({required World world, required Product product}) {
    world.products[product.id] = product;
  }

  // =========================
  // GET PRODUCT
  // =========================

  Product? getProduct({required World world, required String productId}) {
    return world.products[productId];
  }

  // =========================
  // PRICE UPDATE
  // =========================

  int getMarketPrice({required World world, required Product product}) {
    final demand = demandMultiplier(product);

    return (product.baseSalePrice * demand * (1 + world.inflation)).round();
  }

  // =========================
  // DEMAND SYSTEM
  // =========================

  double demandMultiplier(Product product) {
    // Şehir talebi bağlandığında:

    // CitySystem -> ProductSystem

    return 1.0;
  }

  // =========================
  // UPDATE
  // =========================

  void _updateProducts(World world) {
    // Gelecekte:

    // - bozulma
    // - sezon etkisi
    // - şehir talebi
    // - fiyat dalgalanması
  }

  // =========================
  // CHAIN CHECK
  // =========================

  bool canProduce({
    required Product product,

    required Map<String, int> materials,
  }) {
    return product.requiredMaterials.keys.every(
      (key) => materials.containsKey(key),
    );
  }
}
