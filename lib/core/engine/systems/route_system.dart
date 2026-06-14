import 'package:flutter/foundation.dart';

import '../../models/route_model.dart';
import '../game_state.dart';
import 'i_system.dart';

/// Rota yönetim sistemi.
/// Rota CRUD, rota optimizasyonu, rota verimliliği.
class RouteSystem extends ChangeNotifier implements ISystem {
  @override
  String get name => 'RouteSystem';

  @override
  void init(GameState state) {
    debugPrint('[RouteSystem] Initialized - ${state.routes.length} routes');
  }

  @override
  void update(GameState state) {
    // Rota optimizasyonu tick bazlı yapılabilir
  }

  RouteModel? createRoute(
    GameState state, {
    required String id,
    required String source,
    required String destination,
    int trucks = 0,
  }) {
    final existing = state.routes.where(
      (r) => r.source == source && r.destination == destination,
    );
    if (existing.isNotEmpty) {
      debugPrint('[RouteSystem] Route $source -> $destination already exists');
      return null;
    }

    final route = RouteModel(
      id: id,
      source: source,
      destination: destination,
      trucks: trucks,
    );

    state.addRoute(route);
    notifyListeners();
    debugPrint('[RouteSystem] Created route: $id ($source -> $destination)');
    return route;
  }

  void deleteRoute(GameState state, String routeId) {
    state.removeRoute(routeId);
    notifyListeners();
    debugPrint('[RouteSystem] Deleted route: $routeId');
  }

  void updateTruckCount(GameState state, String routeId, int newCount) {
    final route = state.routes.firstWhere(
      (r) => r.id == routeId,
      orElse: () => RouteModel(id: '', source: '', destination: '', trucks: 0),
    );
    if (route.id.isEmpty) return;

    route.trucks = newCount;
    notifyListeners();
    debugPrint('[RouteSystem] Route $routeId trucks: $newCount');
  }

  List<RouteModel> getRoutesBySource(GameState state, String source) {
    return state.routes.where((r) => r.source == source).toList();
  }

  List<RouteModel> getRoutesByDestination(GameState state, String destination) {
    return state.routes.where((r) => r.destination == destination).toList();
  }

  List<RouteModel> getAllRoutes(GameState state) {
    return List.from(state.routes);
  }

  int getActiveRouteCount(GameState state) {
    return state.routes.where((r) => r.trucks > 0).length;
  }

}