class Truck {
  final String id;

  final String name;

  String ownerId;

  int level;

  int capacity;

  double speed;

  String currentCity;

  String targetCity;

  String routeId;

  Map<String, int> cargo;

  DateTime? departureTime;

  DateTime? arrivalTime;

  Truck({
    required this.id,

    required this.name,

    this.ownerId = "",

    this.level = 1,

    this.capacity = 3,

    this.speed = 1.0,

    this.currentCity = "",

    this.targetCity = "",

    this.routeId = "",

    Map<String, int>? cargo,

    this.departureTime,

    this.arrivalTime,
  }) : cargo = cargo ?? {};

  // =========================
  // MOVEMENT
  // =========================

  bool get isMoving {
    if (departureTime == null || arrivalTime == null) {
      return false;
    }

    return DateTime.now().isBefore(arrivalTime!);
  }

  // =========================
  // CARGO
  // =========================

  int get currentLoad {
    return cargo.values.fold(0, (sum, item) => sum + item);
  }

  bool addCargo(String productId, int amount) {
    if (currentLoad + amount > capacity) {
      return false;
    }

    cargo[productId] = (cargo[productId] ?? 0) + amount;

    return true;
  }

  bool removeCargo(String productId, int amount) {
    final current = cargo[productId] ?? 0;

    if (current < amount) {
      return false;
    }

    cargo[productId] = current - amount;

    return true;
  }

  void startRoute({required String destination, required Duration duration}) {
    targetCity = destination;

    departureTime = DateTime.now();

    arrivalTime = DateTime.now().add(duration);
  }

  void arrive() {
    currentCity = targetCity;

    departureTime = null;

    arrivalTime = null;
  }

  void upgrade() {
    level++;

    capacity += 2;

    speed += 0.1;
  }

  // =========================
  // JSON
  // =========================

  Map<String, dynamic> toJson() {
    return {
      "id": id,

      "name": name,

      "ownerId": ownerId,

      "level": level,

      "capacity": capacity,

      "speed": speed,

      "currentCity": currentCity,

      "targetCity": targetCity,

      "routeId": routeId,

      "cargo": cargo,

      "departureTime": departureTime?.toIso8601String(),

      "arrivalTime": arrivalTime?.toIso8601String(),
    };
  }

  factory Truck.fromJson(Map<String, dynamic> json) {
    return Truck(
      id: json["id"],

      name: json["name"],

      ownerId: json["ownerId"] ?? "",

      level: json["level"] ?? 1,

      capacity: json["capacity"] ?? 3,

      speed: (json["speed"] ?? 1.0).toDouble(),

      currentCity: json["currentCity"] ?? "",

      targetCity: json["targetCity"] ?? "",

      routeId: json["routeId"] ?? "",

      cargo: Map<String, int>.from(json["cargo"] ?? {}),

      departureTime: json["departureTime"] == null
          ? null
          : DateTime.parse(json["departureTime"]),

      arrivalTime: json["arrivalTime"] == null
          ? null
          : DateTime.parse(json["arrivalTime"]),
    );
  }
}
