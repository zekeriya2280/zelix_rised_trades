/// File : lib/core/save_manager.dart
/// Version : 1.0.0
/// Status : Stable

import 'dart:convert';

import 'world.dart';

abstract interface class SaveAdapter {
  Future<void> save(String data);

  Future<String?> load();
}

class SaveManager {
  final SaveAdapter adapter;

  SaveManager({required this.adapter});

  Future<void> save(World world) async {
    await adapter.save(jsonEncode(world.toJson()));
  }

  Future<void> load(World world) async {
    final json = await adapter.load();

    if (json == null) return;

    world.loadFromJson(jsonDecode(json));
  }
}
