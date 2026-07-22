/// File : lib/core/system.dart
/// Version : 1.0.0
/// Status : Stable

import 'world.dart';

abstract interface class GameSystem {
  /// Küçük sayı önce çalışır.
  int get priority;

  /// Oyun başlatılırken bir kez çağrılır.
  void initialize(World world) {}

  /// Her tick çağrılır.
  void update(World world, Duration deltaTime);

  /// Oyun kapatılırken çağrılır.
  void dispose() {}
}
