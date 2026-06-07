class Building {
  final String name;
  final String emoji;
  final String description;

  int cost;
  int count;

  Building({
    required this.name,
    required this.emoji,
    required this.description,
    required this.cost,
    this.count = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'cost': cost,
      'count': count,
    };
  }

  factory Building.fromMap(
    Map<String,dynamic> map,
  ) {
    return Building(
      name: map['name'],
      emoji: '',
      description: '',
      cost: map['cost'],
      count: map['count'],
    );
  }
}