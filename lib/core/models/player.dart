class Player {
  String nickname;
  int money;

  Player({
    required this.nickname, 
    required this.money,
  });

  Map<String,dynamic> toMap() {
    return {
      'nickname': nickname,
      'money': money,
    };
  }

  factory Player.fromMap(
    Map<String,dynamic> map,
  ) {
    return Player(  
      nickname: map['nickname'] ?? '',
      money: map['money'],
    );
  }
}