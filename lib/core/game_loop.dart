// 104. Adım
//
// GameLoop → Engine update bağlantısı
//
// Amaç:
// - GameLoop her tick'te Engine'i çalıştıracak
// - Üretim, kamyon, ekonomi sistemleri gerçek zaman ilerleyecek
// - Tekrar UI bağımlılığı olmayacak
//
// Akış:
//
// Timer / Frame Tick
//        ↓
// GameLoop
//        ↓
// Engine.update()
//        ↓
// Systems.update()
//        ↓
// World değişir
//
// Oyun döngülerinde update fonksiyonuna geçen zaman farkı (delta time),
// cihaz hızından bağımsız davranış için kullanılır. :contentReference[oaicite:0]{index=0}

// lib/core/game_loop.dart

import 'dart:async';

import 'engine.dart';

class GameLoop {
  final Engine engine;

  Timer? _timer;

  bool running = false;

  DateTime? _lastUpdate;

  GameLoop({required this.engine});

  // =========================
  // START
  // =========================

  void start() {
    if (running) {
      return;
    }

    running = true;

    _lastUpdate = DateTime.now();

    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _tick();
    });
  }

  // =========================
  // TICK
  // =========================

  void _tick() {
    if (!running) {
      return;
    }

    final now = DateTime.now();

    final delta = now.difference(_lastUpdate!);

    _lastUpdate = now;

    engine.update(delta);
  }

  // =========================
  // STOP
  // =========================

  void stop() {
    running = false;

    _timer?.cancel();

    _timer = null;
  }
}
