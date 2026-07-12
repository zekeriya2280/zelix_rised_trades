import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:zelix_rised_trades/core/engine/game_engine.dart';
import 'package:zelix_rised_trades/core/services/hive_service.dart';

/// Widget tests run without calling app main().
/// This helper initializes Hive + GameEngine so screens depending on systems can build.
class GameEngineTestHelper {
  static bool _didInit = false;

  static Future<GameEngine> initEngineIfNeeded() async {
    if (!_didInit) {
      // Hive init: use system temp so it works in tests.
      Hive.init(Directory.systemTemp.path);
      await HiveService().init();
      _didInit = true;
    }

    final engine = GameEngine();

    // IMPORTANT:
    // game_engine.start() starts a periodic Timer every second.
    // That keeps widget tests running indefinitely unless we avoid starting the tick.
    // So we only ensure systems are initialized via a lightweight init path.
    // If the engine isn't running, initialize systems by calling start(), but immediately stop.
    if (!engine.isRunning) {
      engine.start();
      engine.stop();
    }

    return engine;
  }

}


