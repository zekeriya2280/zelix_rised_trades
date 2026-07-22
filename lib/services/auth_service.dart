// lib/services/auth_service.dart
// 83. Adım
//
// Auth Service
//
// Görev:
// - Kullanıcı giriş işlemleri
// - Anonymous hesap
// - Kullanıcı durumu kontrolü
// - Çıkış işlemi
//
// Firebase Authentication Flutter tarafında kullanıcı kimliği,
// oturum yönetimi ve farklı giriş yöntemleri sağlar.
// ([firebase.google.com](https://firebase.google.com/docs/auth/flutter/start))

import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // =========================
  // CURRENT USER
  // =========================

  User? get currentUser {
    return _auth.currentUser;
  }

  String? get uid {
    return _auth.currentUser?.uid;
  }

  // =========================
  // ANONYMOUS LOGIN
  // =========================

  Future<UserCredential> signInAnonymous() async {
    return await _auth.signInAnonymously();
  }

  // =========================
  // EMAIL REGISTER
  // =========================

  Future<UserCredential> register(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,

      password: password,
    );
  }

  // =========================
  // EMAIL LOGIN
  // =========================

  Future<UserCredential> login(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,

      password: password,
    );
  }

  // =========================
  // AUTH STATE
  // =========================

  Stream<User?> authState() {
    return _auth.authStateChanges();
  }

  // =========================
  // LOGOUT
  // =========================

  Future<void> logout() async {
    await _auth.signOut();
  }
}
