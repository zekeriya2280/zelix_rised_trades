/// File : lib/core/engine.dart
/// Version : 1.0.0
/// Status : Stable

import 'world.dart';
import 'system_manager.dart';

class GameEngine {
  final World world;
  final SystemManager systems;

  bool _initialized = false;

  GameEngine({required this.world, required this.systems});

  bool get initialized => _initialized;

  void initialize() {
    if (_initialized) return;

    systems.initialize(world);

    _initialized = true;
  }

  void update(Duration deltaTime) {
    if (!_initialized) return;

    if (world.paused) return;

    world.advanceTime(deltaTime);

    systems.update(world, deltaTime);
  }

  void dispose() {
    systems.dispose();
  }
}
