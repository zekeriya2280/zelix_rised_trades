import 'package:zelix_rised_trades/core/enums/resource_type.dart';

enum FactoryType { forest, lumberMill, furnitureFactory }

extension FactoryTypeData on FactoryType {
  int get productionSeconds {
    switch (this) {
      case FactoryType.forest:
        return 5;
      case FactoryType.lumberMill:
        return 10;
      case FactoryType.furnitureFactory:
        return 20;
    }
  }

  ResourceType get output {
    switch (this) {
      case FactoryType.forest:
        return ResourceType.wood;

      case FactoryType.lumberMill:
        return ResourceType.lumber;

      case FactoryType.furnitureFactory:
        return ResourceType.furniture;
    }
  }

  int get outputAmount {
    switch (this) {
      case FactoryType.forest:
        return 5;

      case FactoryType.lumberMill:
        return 5;

      case FactoryType.furnitureFactory:
        return 2;
    }
  }
  ResourceType? get input {

  switch(this){

    case FactoryType.forest:
      return null;

    case FactoryType.lumberMill:
      return ResourceType.wood;

    case FactoryType.furnitureFactory:
      return ResourceType.lumber;
  }
}
int get inputAmount {

  switch(this){

    case FactoryType.forest:
      return 0;

    case FactoryType.lumberMill:
      return 10;

    case FactoryType.furnitureFactory:
      return 10;
  }
}
}
