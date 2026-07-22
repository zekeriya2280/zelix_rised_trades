import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';

import 'package:provider/provider.dart';

import 'app.dart';

import 'services/game_service.dart';

import 'core/game_initializer.dart';

import 'repositories/firebase_repository.dart';

import 'ui/providers/game_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: 'AIzaSyBOZfkXHLA2A2yplftJWwYs1J30NWUXugo',
      appId: '1:334022833215:android:12ed0198fb278aef0b348a',
      messagingSenderId: '334022833215',
      projectId: 'zelix-rised-trades',
      storageBucket: 'zelix-rised-trades.firebasestorage.app',
    ),
  );

  final firebaseRepository = FirebaseRepository();

  final gameInitializer = GameInitializer();

  final gameService = GameService(
    initializer: gameInitializer,

    firebaseRepository: firebaseRepository,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) {
            final provider = GameProvider(gameService: gameService);

            provider.initialize();

            return provider;
          },
        ),
      ],

      child: const ZelixApp(),
    ),
  );
}
