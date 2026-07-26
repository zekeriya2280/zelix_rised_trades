import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/world.dart';

class FirebaseRepository {
  final FirebaseFirestore firestore;

  FirebaseRepository({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  // =========================
  // SAVE WORLD
  // =========================

  Future<void> saveWorld(World world) async {
    await firestore
        .collection("players")
        .doc(world.playerId)
        .set(world.toJson());
  }

  // =========================
  // LOAD WORLD
  // =========================

  Future<World?> loadWorld(String playerId) async {
    try {
      final snapshot = await firestore
          .collection("players")
          .doc(playerId)
          .get();

      debugPrint("Firebase loaded");

      if (!snapshot.exists) {
        debugPrint("No save");

        return null;
      }

      return World.fromJson(snapshot.data()!);
    } catch (e) {
      debugPrint("Firebase error: $e");

      return null;
    }
  }

  // =========================
  // DELETE WORLD
  // =========================

  Future<void> deleteWorld(String playerId) async {
    await firestore.collection("players").doc(playerId).delete();
  }
}
