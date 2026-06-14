import 'package:flutter/foundation.dart';

import '../../enums/resource_type.dart';
import '../../models/city.dart';
import '../game_state.dart';
import 'i_system.dart';

/// Şehir yönetim sistemi.
/// Şehir CRUD, talep yönetimi, şehirler arası ticaret.
class CitySystem extends ChangeNotifier implements ISystem {
  @override
  String get name => 'CitySystem';

  @override
  void init(GameState state) {
    debugPrint('[CitySystem] Initialized - ${state.cities.length} cities');
  }

  @override
  void update(GameState state) {
    // Talep kontrolü ve ticaret tick'te işlenebilir
  }

  City? createCity(
    GameState state, {
    required String id,
    required String name,
    Map<ResourceType, int>? demand,
  }) {
    if (state.cities.any((c) => c.id == id)) {
      debugPrint('[CitySystem] City $id already exists');
      return null;
    }

    final city = City(
      id: id,
      name: name,
      demand: demand ?? <ResourceType, int>{},
    );

    state.cities.add(city);
    notifyListeners();
    debugPrint('[CitySystem] Created city: $id ($name)');
    return city;
  }

  void updateDemand(
    GameState state,
    String cityId,
    ResourceType type,
    int amount,
  ) {
    final city = _findCity(state, cityId);
    if (city == null) return;

    city.demand[type] = amount;
    notifyListeners();
    debugPrint('[CitySystem] Updated demand: $cityId, ${type.name}=$amount');
  }

  int getDemand(GameState state, String cityId, ResourceType type) {
    final city = _findCity(state, cityId);
    if (city == null) return 0;
    return city.demand[type] ?? 0;
  }

  Map<ResourceType, int> getTotalDemand(GameState state) {
    final total = <ResourceType, int>{
      for (final type in ResourceType.values) type: 0,
    };

    for (final city in state.cities) {
      for (final entry in city.demand.entries) {
        total[entry.key] = (total[entry.key] ?? 0) + entry.value;
      }
    }

    return total;
  }

  List<City> getCitiesWithDemand(GameState state) {
    return state.cities.where((c) => c.demand.isNotEmpty).toList();
  }

  List<City> getAllCities(GameState state) {
    return List.from(state.cities);
  }

  City? _findCity(GameState state, String cityId) {
    try {
      return state.cities.firstWhere((c) => c.id == cityId);
    } catch (_) {
      return null;
    }
  }

}