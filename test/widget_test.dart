import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zelix_rised_trades/main.dart';
import 'package:zelix_rised_trades/core/engine/game_engine.dart';
import 'game_engine_test_helper.dart';

void main() {
  testWidgets('MyApp builds without throwing', (tester) async {
    // In widget tests, main() is not executed.
    // Initialize the engine so BuildingShopScreen can access systems.
    await GameEngineTestHelper.initEngineIfNeeded();

    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);

    // Stop any engine timer started by start().
    // (Defensive: tests may run in parallel with previous helpers.)
    GameEngine().stop();

  });
}



