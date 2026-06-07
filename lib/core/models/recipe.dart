import '../enums/resource_type.dart';

class Recipe {
  final ResourceType input;

  final ResourceType output;

  final int inputAmount;

  final int outputAmount;

  Recipe({
    required this.input,
    required this.output,
    required this.inputAmount,
    required this.outputAmount,
  });
}