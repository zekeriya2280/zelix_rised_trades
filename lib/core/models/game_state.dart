import 'city.dart';
import 'factory.dart';
import 'route_model.dart';
import 'truck.dart';
import 'warehouse.dart';

class GameState {
  final Warehouse warehouse;

  final List<Factory> factories;

  final List<Truck> trucks;

  final List<RouteModel> routes;

  final List<City> cities;

  GameState({
    required this.warehouse,
    required this.factories,
    required this.trucks,
    required this.routes,
    required this.cities,
  });
}