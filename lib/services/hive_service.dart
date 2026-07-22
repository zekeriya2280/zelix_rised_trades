import 'package:hive/hive.dart';

import '../repositories/hive_repository.dart';
import '../core/world.dart';

class HiveService {
  final HiveRepository repository;
  final Box box;

  HiveService({required this.repository, required this.box});

  Future<void> saveWorld(World world) async {
    await repository.saveWorld(world);
  }

  Future<Map<String, dynamic>?> loadWorld() async {
    final data = await repository.loadWorld();

    if (data == null) {
      return null;
    }

    return data;
  }

  bool hasSave() {
    return box.containsKey("world");
  }

  Future<void> deleteSave() async {
    await box.delete("world");
  }
}
