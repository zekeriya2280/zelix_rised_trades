import 'dart:async';

class GameEngine {

  Timer? _timer;

  final void Function() onTick;

  GameEngine({
    required this.onTick,
  });

  void start() {

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {

        onTick();

      },
    );
  }

  void stop() {
    _timer?.cancel();
  }
}