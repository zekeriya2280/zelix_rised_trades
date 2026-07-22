/// File : lib/core/repository.dart
/// Version : 1.0.0
/// Status : Stable

import 'world.dart';

abstract interface class Repository {
  Future<void> initialize();

  Future<void> save(World world);

  Future<void> load(World world);

  Future<void> clear();

  Future<void> dispose();
}
