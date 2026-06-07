import '../enums/resource_type.dart';
import '../models/recipe.dart';

final lumberRecipe = Recipe(
  input: ResourceType.wood,
  output: ResourceType.lumber,
  inputAmount: 10,
  outputAmount: 5,
);

final furnitureRecipe = Recipe(
  input: ResourceType.lumber,
  output: ResourceType.furniture,
  inputAmount: 10,
  outputAmount: 2,
);