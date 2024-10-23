import 'dart:async';
import 'dart:ui';

import '../utils/log.dart';

class TimerService {
  // Singleton Pattern
  TimerService._();
  static final TimerService _instance = TimerService._();
  factory TimerService() => _instance;

  // Duración del tick
  static const tickDuration = Duration(milliseconds: 500);

  // Mapa que asocia el ID del cronómetro con su Timer
  final Map<int, Timer> _timers = {};

  // Inicia el cronómetro
  void startTimer(int id, VoidCallback onTick,
      {Duration syncTime = Duration.zero}) {
    if (isRunning(id)) return;

    // Inicia el cronómetro al segundo en punto de [syncTime]
    _atStartOfNextSecond(id, syncTime, () {
      _timers[id] = Timer.periodic(tickDuration, (timer) {
        onTick();
      });
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

  /// Execute [onNextSecond] at the next beginning of second of [syncTime]
  void _atStartOfNextSecond(
      int id, Duration syncTime, VoidCallback onNextSecond) {
    int fractionMicroseconds =
        syncTime.inMicroseconds.remainder(Duration.microsecondsPerSecond);
    Duration remainingTimeToNextSecond = Duration(
      microseconds: fractionMicroseconds > 0
          ? (Duration.microsecondsPerSecond - fractionMicroseconds)
          : 0,
    );
    log(enabled: false, 'Start timer in: $remainingTimeToNextSecond');
    _timers[id] = Timer(
      remainingTimeToNextSecond,
      onNextSecond,
    );
  }
}
