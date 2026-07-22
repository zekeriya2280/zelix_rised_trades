// lib/services/firebase_service.dart
// 81. Adım
//
// Firebase Service
//
// Görev:
// - Firebase bağlantı katmanı
// - Kullanıcı verisi
// - Cloud save hazırlığı
// - Single Player -> Multiplayer geçiş altyapısı
//
// Firestore Flutter tarafında veri saklama ve senkronizasyon için kullanılır.
// Firebase Authentication kullanıcı kimliği sağlar.
// :contentReference[oaicite:0]{index=0}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // =========================
  // AUTH
  // =========================

  Future<String?> signInAnonymous() async {
    final result = await _auth.signInAnonymously();

    return result.user?.uid;
  }

  String? get currentUserId {
    return _auth.currentUser?.uid;
  }

  // =========================
  // SAVE PLAYER
  // =========================

  Future<void> savePlayerData({
    required String uid,

    required Map<String, dynamic> data,
  }) async {
    await _firestore
        .collection("players")
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  // =========================
  // LOAD PLAYER
  // =========================

  Future<Map<String, dynamic>?> loadPlayerData(String uid) async {
    final snapshot = await _firestore.collection("players").doc(uid).get();

    if (!snapshot.exists) {
      return null;
    }

    return snapshot.data();
  }

  // =========================
  // DELETE PLAYER
  // =========================

  Future<void> deletePlayerData(String uid) async {
    await _firestore.collection("players").doc(uid).delete();
  }
}
