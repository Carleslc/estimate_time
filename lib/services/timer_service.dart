import 'dart:async';
import 'dart:ui';

import '../utils/duration.dart';
import '../utils/log.dart';

class TimerService {
  // Duración del tick
  final Duration tickDuration;

  TimerService({Duration? tickDuration})
      : tickDuration = tickDuration ?? const Duration(seconds: 1);

  // Mapa que asocia el ID del cronómetro con su Timer
  final Map<int, Timer> _timers = {};

  // Inicia el cronómetro
  void startTimer(
    int id, {
    required VoidCallback onTick,
    Duration? syncTime,
    VoidCallback? onFirstTick,
  }) {
    if (isRunning(id)) return;

    // Inicia el cronómetro
    final startTimeCallback = () {
      // Primer tick
      (onFirstTick ?? onTick).call();
      // Ticks en intervalos de [tickDuration]
      if (syncTime == null || isRunning(id)) {
        _timers[id] = Timer.periodic(tickDuration, (timer) {
          onTick();
        });
      }
    };
    if (syncTime != null) {
      // Primer tick al siguiente segundo en punto de [syncTime]
      _atStartOfNextSecond(id, syncTime, startTimeCallback);
    } else {
      // Primer tick inmediatamente
      startTimeCallback();
    }
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
      microseconds: Duration.microsecondsPerSecond - fractionMicroseconds,
    );
    log(
        enabled: false,
        'Next second in: ${remainingTimeToNextSecond.totalSeconds.toStringAsFixed(3)} s');
    _timers[id] = Timer(
      remainingTimeToNextSecond,
      onNextSecond,
    );
  }
}
