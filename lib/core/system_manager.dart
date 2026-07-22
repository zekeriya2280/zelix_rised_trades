/// File : lib/core/system_manager.dart
/// Version : 1.0.0
/// Status : Stable

import 'system.dart';
import 'world.dart';

class SystemManager {
  final List<GameSystem> _systems = [];

  List<GameSystem> get systems => List.unmodifiable(_systems);

  void add(GameSystem system) {
    _systems.add(system);
    _systems.sort((a, b) => a.priority.compareTo(b.priority));
  }

  void remove(GameSystem system) {
    _systems.remove(system);
  }

  void clear() {
    _systems.clear();
  }

  void initialize(World world) {
    for (final system in _systems) {
      system.initialize(world);
    }
  }

  void update(World world, Duration deltaTime) {
    for (final system in _systems) {
      system.update(world, deltaTime);
    }
  }

  void dispose() {
    for (final system in _systems) {
      system.dispose();
    }

    _systems.clear();
  }
}
