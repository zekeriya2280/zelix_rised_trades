// lib/network/game_command.dart
// 99. Adım
//
// Game Command
//
// Amaç:
// - Client'ın server'a göndereceği hareketleri standartlaştırmak
// - Multiplayer hile kontrolü için komut yapısı oluşturmak
// - UI → Command → Server → System akışı hazırlamak
//
// Command pattern, işlemleri ayrı nesneler olarak temsil ederek
// uygulama mantığını daha düzenli hale getirir. :contentReference[oaicite:0]{index=0}
//
// WebSocket üzerinden JSON mesajları gönderilip alınabilir.
// Flutter'da WebSocket iki yönlü iletişim için Stream/Sink yapısı sağlar. :contentReference[oaicite:1]{index=1}

enum CommandType {
  buyFactory,

  startProduction,

  stopProduction,

  moveTruck,

  loadTruck,

  unloadTruck,

  buyProduct,

  sellProduct,

  upgradeBuilding,
}

class GameCommand {
  final String playerId;

  final CommandType type;

  final Map<String, dynamic> data;

  final DateTime timestamp;

  GameCommand({
    required this.playerId,

    required this.type,

    required this.data,

    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  // =========================
  // JSON
  // =========================

  Map<String, dynamic> toJson() {
    return {
      "playerId": playerId,

      "type": type.name,

      "data": data,

      "timestamp": timestamp.toIso8601String(),
    };
  }

  factory GameCommand.fromJson(Map<String, dynamic> json) {
    return GameCommand(
      playerId: json["playerId"],

      type: CommandType.values.firstWhere(
        (e) => e.name == json["type"],

        orElse: () => CommandType.buyProduct,
      ),

      data: Map<String, dynamic>.from(json["data"] ?? {}),

      timestamp: DateTime.parse(json["timestamp"]),
    );
  }
}
