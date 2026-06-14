import '../game_state.dart';

/// Tüm sistemler için temel arayüz.
/// Her sistem kendi sorumluluk alanında çalışır.
abstract class ISystem {
  /// Sistem adı (debug/log için)
  String get name;

  /// State'i başlatma (ör: varsayılan değerler)
  void init(GameState state);

  /// Her tick'te çağrılır
  void update(GameState state);

  /// Sistemi dispose et
  void dispose();
}