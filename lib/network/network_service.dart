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

import 'package:web_socket_channel/web_socket_channel.dart';

class NetworkService {
  WebSocketChannel? _channel;

  bool connected = false;

  // =========================
  // CONNECT
  // =========================

  Future<void> connect(String url) async {
    _channel = WebSocketChannel.connect(Uri.parse(url));

    connected = true;
  }

  // =========================
  // RECEIVE
  // =========================

  Stream<Map<String, dynamic>> messages() {
    if (_channel == null) {
      return const Stream.empty();
    }

    return _channel!.stream.map((event) {
      return jsonDecode(event);
    });
  }

  // =========================
  // SEND COMMAND
  // =========================

  void send(Map<String, dynamic> data) {
    if (!connected) {
      return;
    }

    _channel!.sink.add(jsonEncode(data));
  }

  // =========================
  // DISCONNECT
  // =========================

  Future<void> disconnect() async {
    await _channel!.sink.close();

    connected = false;

    _channel = null;
  }
}
