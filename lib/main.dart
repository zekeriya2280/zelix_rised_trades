import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/engine/game_engine.dart';
import 'core/services/firestore_service.dart';
import 'screens/building_shop_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirestoreService.markFirebaseAvailable();
  } catch (e) {
    // Firebase initialization may fail on emulators without Google Play Services.
    // The app will still function, but Firebase features won't be available.
    debugPrint('Firebase initialization failed: $e');
  }

  // Start the game engine (singleton) – it will stream factory & warehouse
  // data from Firebase every second and run auto-production logic.
  GameEngine().start();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Zelix Rised Trades',
      theme: ThemeData(useMaterial3: true),
      home: const BuildingShopScreen(),
    );
  }
}
