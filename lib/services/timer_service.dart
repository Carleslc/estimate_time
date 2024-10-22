import 'dart:async';

class TimerService {
  // Singleton Pattern
  TimerService._();
  static final TimerService _instance = TimerService._();
  factory TimerService() => _instance;

  // Duración del tick
  static const tickDuration = Duration(seconds: 1);

  // Mapa que asocia el ID del cronómetro con su Timer
  final Map<int, Timer> _timers = {};

  // Inicia el cronómetro
  void startTimer(int id, Function onTick) {
    if (_timers.containsKey(id)) return; // Ya está corriendo

    _timers[id] = Timer.periodic(tickDuration, (timer) {
      onTick();
    });
  }

  // Pausa el cronómetro
  void stopTimer(int id) {
    if (_timers.containsKey(id)) {
      _timers[id]?.cancel();
      _timers.remove(id);
    }
  }

  // Verifica si un cronómetro está corriendo
  bool isRunning(int id) {
    return _timers.containsKey(id);
  }

  // Detén todos los cronómetros (por ejemplo, al cerrar la aplicación)
  void stopAll() {
    _timers.forEach((key, timer) => timer.cancel());
    _timers.clear();
  }
}
