import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'core/engine/game_engine.dart';
import 'core/services/hive_service.dart';
import 'screens/building_shop_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive using system temp directory (writable on all platforms)
  // No native plugins needed - pure Dart with no NDK requirement!
  final hiveDir = Directory.systemTemp.path;
  Hive.init(hiveDir);
  await HiveService().init();

  // Start the game engine (singleton) – it will manage factory & warehouse
  // data locally and run auto-production logic.
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