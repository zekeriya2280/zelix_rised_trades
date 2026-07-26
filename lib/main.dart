import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase'i initialize et, zaten initialize edilmişse hatayı yakala ve ignore et
  try {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: "AIzaSyBOZfkXHLA2A2yplftJWwYs1J30NWUXugo",
        appId: "1:334022833215:android:12ed0198fb278aef0b348a",
        messagingSenderId: "334022833215",
        projectId: "zelix-rised-trades",
        storageBucket: "zelix-rised-trades.firebasestorage.app",
      ),
    );
  } catch (e) {
    // Hata "duplicate app" ise ignore et, çünkü Firebase zaten initialize edilmiş
    if (e.toString().contains('duplicate-app') ||
        e.toString().contains('already exists')) {
      // Firebase zaten initialize edilmiş, devam et
    } else {
      // Farklı bir hata, rethrow et
      rethrow;
    }
  }

  runApp(const ZelixApp());
}

// 🤖 CodeWhisperer Test Alanı
// Aşağıdaki yorumları yazıp Tab'a basarak test edin:
