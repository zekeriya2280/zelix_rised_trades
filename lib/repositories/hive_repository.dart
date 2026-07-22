// lib/repositories/hive_repository.dart

import '../core/world.dart';
import '../services/hive_service.dart';

class HiveRepository {
  final HiveService hiveService;

  HiveRepository({required this.hiveService});

  // =========================
  // SAVE
  // =========================

  Future<void> saveWorld(World world) async {
    await hiveService.saveWorld(world);
  }

  // =========================
  // LOAD
  // =========================

  Future<Map<String, dynamic>?> loadWorld() async {
    return await hiveService.loadWorld();
  }

  // =========================
  // CHECK SAVE
  // =========================

  bool exists() {
    return hiveService.hasSave();
  }

  // =========================
  // DELETE
  // =========================

  Future<void> delete() async {
    await hiveService.deleteSave();
  }
}
