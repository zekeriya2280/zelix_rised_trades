// lib/network/network_service.dart
// 98. Adım
//
// Network Service
//
// Amaç:
// - Client ↔ Server bağlantı katmanı
// - Multiplayer gerçek zamanlı iletişim hazırlığı
// - WebSocket altyapısı
// - Firebase yerine gerçek oyun serverına geçiş noktası
//
// WebSocket iki yönlü sürekli iletişim sağlar.
// Multiplayer oyunlarda client'ın server'a komut göndermesi
// ve server'ın state güncellemesi için kullanılabilir.
// ([docs.flutter.dev](https://docs.flutter.dev/cookbook/networking/web-sockets))

import 'dart:convert';

// Web socket channel için placeholder
// Pubspec.yaml'da web_socket_channel paketi eklendiğinde açılabilir
// import 'package:web_socket_channel/web_socket_channel.dart';

class NetworkService {
  // TODO: web_socket_channel paketi eklendiğinde implement edilecek
  bool connected = false;

  // =========================
  // CONNECT
  // =========================

  Future<void> connect(String url) async {
    // _channel = WebSocketChannel.connect(Uri.parse(url));
    // connected = true;
    // TODO: Firebase yerine gerçek server bağlantısı
    connected = true;
    print('[NetworkService] Connected to $url');
  }

  // =========================
  // RECEIVE
  // =========================

  Stream<Map<String, dynamic>> messages() {
    // TODO: WebSocket implementasyonu eklendiğinde açılacak
    return const Stream.empty();
  }

  // =========================
  // SEND COMMAND
  // =========================

  void send(Map<String, dynamic> data) {
    if (!connected) {
      return;
    }
    // TODO: _channel!.sink.add(jsonEncode(data));
    print('[NetworkService] Sending: ${jsonEncode(data)}');
  }

  // =========================
  // DISCONNECT
  // =========================

  Future<void> disconnect() async {
    // TODO: _channel!.sink.close();
    connected = false;
  }
}
