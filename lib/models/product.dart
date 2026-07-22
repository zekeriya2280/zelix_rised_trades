import 'package:flutter/foundation.dart';

class Product {
  final String id;

  final String name;

  final String category;

  final int level;

  final int basePurchasePrice;

  final int baseSalePrice;

  final double demandIndex;

  final Map<String, int> requiredMaterials;

  final int productionTime;

  final int unlockLevel;

  Product({
    required this.id,

    required this.name,

    required this.category,

    required this.level,

    required this.basePurchasePrice,

    required this.baseSalePrice,

    this.demandIndex = 1.0,

    this.requiredMaterials = const {},

    required this.productionTime,

    this.unlockLevel = 1,
  });

  Product copyWith({
    String? id,

    String? name,

    String? category,

    int? level,

    int? basePurchasePrice,

    int? baseSalePrice,

    double? demandIndex,

    Map<String, int>? requiredMaterials,

    int? productionTime,

    int? unlockLevel,
  }) {
    return Product(
      id: id ?? this.id,

      name: name ?? this.name,

      category: category ?? this.category,

      level: level ?? this.level,

      basePurchasePrice: basePurchasePrice ?? this.basePurchasePrice,

      baseSalePrice: baseSalePrice ?? this.baseSalePrice,

      demandIndex: demandIndex ?? this.demandIndex,

      requiredMaterials: requiredMaterials ?? this.requiredMaterials,

      productionTime: productionTime ?? this.productionTime,

      unlockLevel: unlockLevel ?? this.unlockLevel,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,

      "name": name,

      "category": category,

      "level": level,

      "basePurchasePrice": basePurchasePrice,

      "baseSalePrice": baseSalePrice,

      "demandIndex": demandIndex,

      "requiredMaterials": requiredMaterials,

      "productionTime": productionTime,

      "unlockLevel": unlockLevel,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json["id"],

      name: json["name"],

      category: json["category"],

      level: json["level"] ?? 1,

      basePurchasePrice: json["basePurchasePrice"] ?? 0,

      baseSalePrice: json["baseSalePrice"] ?? 0,

      demandIndex: (json["demandIndex"] ?? 1.0).toDouble(),

      requiredMaterials: Map<String, int>.from(json["requiredMaterials"] ?? {}),

      productionTime: json["productionTime"] ?? 60,

      unlockLevel: json["unlockLevel"] ?? 1,
    );
  }
}
