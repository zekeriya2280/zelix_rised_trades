/// File : lib/core/scheduler.dart
/// Version : 1.0.0
/// Status : Stable

import 'dart:async';

import 'engine.dart';

class Scheduler {
  final GameEngine engine;

  final int ticksPerSecond;

  Timer? _timer;

  DateTime? _lastUpdate;

  Scheduler({required this.engine, this.ticksPerSecond = 20});

  bool get isRunning => _timer != null;

  void start() {
    if (isRunning) return;

    engine.initialize();

    _lastUpdate = DateTime.now();

    _timer = Timer.periodic(
      Duration(milliseconds: 1000 ~/ ticksPerSecond),
      _update,
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();

    engine.dispose();
  }

  void _update(Timer timer) {
    final now = DateTime.now();

    final delta = now.difference(_lastUpdate!);

    _lastUpdate = now;

    engine.update(delta);
  }
}
