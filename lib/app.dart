import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:zelix_rised_trades/core/game_initializer.dart';
import 'package:zelix_rised_trades/repositories/firebase_repository.dart';
import 'package:zelix_rised_trades/services/game_service.dart';
import 'package:zelix_rised_trades/ui/providers/game_provider.dart';

import 'ui/screens/game_screen.dart';

class ZelixApp extends StatelessWidget {
  const ZelixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zelix Rised Trades',
      debugShowCheckedModeBanner: false,

      themeMode: ThemeMode.system,

      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.light,
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
      ),

      home: GameScreen(
        provider: GameProvider(
          gameService: GameService(
            initializer: GameInitializer(),
            firebaseRepository: FirebaseRepository(
              firestore: FirebaseFirestore.instance,
            ),
          ),
        ),
      ),
    );
  }
}
