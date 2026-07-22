class Factory {
  final String id;

  final String name;

  final String type;

  int level;

  String ownerId;

  String locationId;

  String outputProduct;

  int productionAmount;

  int productionTime;

  Map<String, int> requiredMaterials;

  bool isRunning;

  DateTime lastProductionTime;

  int upgradeCost;

  Factory({
    required this.id,

    required this.name,

    required this.type,

    this.level = 1,

    this.ownerId = "",

    this.locationId = "",

    required this.outputProduct,

    required this.productionAmount,

    required this.productionTime,

    this.requiredMaterials = const {},

    this.isRunning = false,

    DateTime? lastProductionTime,

    this.upgradeCost = 1000,
  }) : lastProductionTime = lastProductionTime ?? DateTime.now();

  bool get canProduce => isRunning;

  void start() {
    isRunning = true;
  }

  void stop() {
    isRunning = false;
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,

      "name": name,

      "type": type,

      "level": level,

      "ownerId": ownerId,

      "locationId": locationId,

      "outputProduct": outputProduct,

      "productionAmount": productionAmount,

      "productionTime": productionTime,

      "requiredMaterials": requiredMaterials,

      "isRunning": isRunning,

      "lastProductionTime": lastProductionTime.toIso8601String(),

      "upgradeCost": upgradeCost,
    };
  }

  factory Factory.fromJson(Map<String, dynamic> json) {
    return Factory(
      id: json["id"],

      name: json["name"],

      type: json["type"] ?? "factory",

      level: json["level"] ?? 1,

      ownerId: json["ownerId"] ?? "",

      locationId: json["locationId"] ?? "",

      outputProduct: json["outputProduct"],

      productionAmount: json["productionAmount"] ?? 1,

      productionTime: json["productionTime"] ?? 60,

      requiredMaterials: Map<String, int>.from(json["requiredMaterials"] ?? {}),

      isRunning: json["isRunning"] ?? false,

      lastProductionTime: DateTime.parse(json["lastProductionTime"]),

      upgradeCost: json["upgradeCost"] ?? 1000,
    );
  }
}
