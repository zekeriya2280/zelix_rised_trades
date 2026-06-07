import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zelix_rised_trades/provider/game_notifier.dart';
import '../core/enums/resource_type.dart';
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {

    final game =
        ref.watch(gameProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Zelix RiseD Trades',
        ),
      ),
      body: Column(
        children: [

          Text(
            'Wood: ${game.warehouse.get(ResourceType.wood)}',
          ),

          Text(
            'Lumber: ${game.warehouse.get(ResourceType.lumber)}',
          ),

          Text(
            'Furniture: ${game.warehouse.get(ResourceType.furniture)}',
          ),
        ],
      ),
    );
  }
}