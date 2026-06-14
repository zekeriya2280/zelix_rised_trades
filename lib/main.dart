import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'core/engine/game_engine.dart';
import 'core/services/hive_service.dart';
import 'screens/building_shop_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive using system temp directory (writable on all platforms)
  final hiveDir = Directory.systemTemp.path;
  Hive.init(hiveDir);
  await HiveService().init();

  // Start the game engine – manages all systems (factory, warehouse, player, etc.)
  // UI communicates ONLY through GameEngine, never directly with HiveService.
  GameEngine().start();

  runApp(const MyApp());
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