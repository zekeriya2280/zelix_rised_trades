// lib/network/server_state.dart
// 101. Adım
//
// Server State
//
// Amaç:
// - Server'ın gönderdiği doğrulanmış oyun durumunu tutmak
// - Client World ile server World ayrımı
// - Multiplayer senkronizasyon noktası
//
// Multiplayer oyunlarda genellikle server gerçek state kaynağı olur.
// Client komut gönderir, server doğrular ve güncel state döner.
// Flutter mimarisinde de tek bir "source of truth" yaklaşımı önerilir.
// :contentReference[oaicite:0]{index=0}

import '../core/world.dart';

class ServerState {
  World? world;

  int tick;

  DateTime lastSync;

  ServerState({this.world, this.tick = 0, DateTime? lastSync})
    : lastSync = lastSync ?? DateTime.now();

  // =========================
  // APPLY SERVER UPDATE
  // =========================

  void update(World newWorld) {
    world = newWorld;

    tick++;

    lastSync = DateTime.now();
  }

  // =========================
  // GET STATE
  // =========================

  World? get currentWorld {
    return world;
  }

  // =========================
  // JSON
  // =========================

  Map<String, dynamic> toJson() {
    return {
      "tick": tick,

      "lastSync": lastSync.toIso8601String(),

      "world": world?.toJson(),
    };
  }

  factory ServerState.fromJson(Map<String, dynamic> json) {
    return ServerState(
      tick: json["tick"] ?? 0,

      lastSync: DateTime.parse(json["lastSync"]),

      world: json["world"] == null ? null : World.fromJson(json["world"]),
    );
  }
}
