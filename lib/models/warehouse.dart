class Warehouse {
  final String id;

  final String name;

  String ownerId;

  String cityId;

  int capacity;

  int level;

  Map<String, int> products;

  Warehouse({
    required this.id,

    required this.name,

    this.ownerId = "",

    this.cityId = "",

    this.capacity = 500,

    this.level = 1,

    Map<String, int>? products,
  }) : products = products ?? {};

  // =========================
  // ADD PRODUCT
  // =========================

  bool addProduct(String productId, int amount) {
    if (currentCapacity + amount > capacity) {
      return false;
    }

    products[productId] = (products[productId] ?? 0) + amount;

    return true;
  }

  // =========================
  // REMOVE PRODUCT
  // =========================

  bool removeProduct(String productId, int amount) {
    final current = products[productId] ?? 0;

    if (current < amount) {
      return false;
    }

    products[productId] = current - amount;

    return true;
  }

  // =========================
  // GET PRODUCT
  // =========================

  int getProduct(String productId) {
    return products[productId] ?? 0;
  }

  // =========================
  // CAPACITY
  // =========================

  int get currentCapacity {
    return products.values.fold(0, (sum, item) => sum + item);
  }

  int get freeCapacity {
    return capacity - currentCapacity;
  }

  // =========================
  // UPGRADE
  // =========================

  void upgrade() {
    level++;

    capacity += 500;
  }

  // =========================
  // JSON
  // =========================

  Map<String, dynamic> toJson() {
    return {
      "id": id,

      "name": name,

      "ownerId": ownerId,

      "cityId": cityId,

      "capacity": capacity,

      "level": level,

      "products": products,
    };
  }

  factory Warehouse.fromJson(Map<String, dynamic> json) {
    return Warehouse(
      id: json["id"],

      name: json["name"],

      ownerId: json["ownerId"] ?? "",

      cityId: json["cityId"] ?? "",

      capacity: json["capacity"] ?? 500,

      level: json["level"] ?? 1,

      products: Map<String, int>.from(json["products"] ?? {}),
    );
  }
}
