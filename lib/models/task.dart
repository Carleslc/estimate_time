import 'package:isar/isar.dart';

import '../utils/date.dart';
import '../utils/duration.dart';
import '../utils/log.dart';
import 'project.dart';
import 'time_entry.dart';

part 'task.g.dart';

@Collection()
class Task {
  Id id = Isar.autoIncrement;

  /// Título de la tarea
  late String title;

  /// Descripción de la tarea
  late String description;

  /// Referencia opcional al proyecto
  @Index()
  final project = IsarLink<Project>();

  /// Tiempo estimado en milisegundos
  int? get estimatedTimeMillis => _estimatedTimeMillis;
  @ignore
  int? _estimatedTimeMillis;

  set estimatedTimeMillis(int? value) {
    _estimatedTimeMillis = value;
    _updateDeviation();
  }

  /// Tiempo total acumulado en milisegundos
  int get totalTimeMillis => _totalTimeMillis;
  @ignore
  int _totalTimeMillis = 0;

  set totalTimeMillis(int value) {
    _totalTimeMillis = value;
    _updateDeviation();
  }

  /// Fecha de última actualización del tiempo registrado
  DateTime lastUpdated = DateTime.now();

  /// Estado del cronómetro
  bool isRunning = false;

  /// Estado de la tarea (activa / archivada)
  bool archived = false;

  /// Historial de tiempo por día
  final timeHistory = IsarLinks<TimeEntry>();

  /// Último tiempo diario registrado
  @ignore
  TimeEntry? get lastTimeEntry => timeHistory.lastOrNull;

  /// Tiempo registrado hoy
  @ignore
  TimeEntry? todayTimeEntry;

  /// Progreso estimado
  @ignore
  double get progressEstimation => _progressEstimation;
  @ignore
  double _progressEstimation = 0;

  /// Desviación calculada
  @ignore
  double get deviation => _deviation;
  @ignore
  double _deviation = 0;

  /// Duración estimada
  @ignore
  Duration? get estimatedTime => _estimatedTimeMillis != null
      ? Duration(milliseconds: _estimatedTimeMillis!)
      : null;

  set estimatedTime(Duration? duration) {
    estimatedTimeMillis = duration?.inMilliseconds;
  }

  /// Tiempo total acumulado
  @ignore
  Duration get totalTime => Duration(milliseconds: _totalTimeMillis);

  set totalTime(Duration duration) {
    totalTimeMillis = duration.inMilliseconds;
  }

  /// Tiempo registrado hoy en milisegundos
  @ignore
  int? get todayTimeMillis => todayTimeEntry?.milliseconds;

  /// Tiempo registrado hoy
  @ignore
  Duration? get todayTime =>
      todayTimeMillis != null ? Duration(milliseconds: todayTimeMillis!) : null;

  /// Get linked project
  Future<Project?> getProject() async {
    if (project.value == null) return null;
    await project.load();
    return project.value;
  }

  /// Link project
  void setProject(Project? project) {
    this.project.value = project;
  }

  @ignore
  String get timerLabel {
    if (isRunning) {
      return 'Pausar';
    } else if (_totalTimeMillis > 0) {
      return 'Reanudar';
    } else {
      return 'Empezar';
    }
  }

  /// Calcular desviación
  void _updateDeviation() {
    if (_estimatedTimeMillis != null) {
      _progressEstimation =
          calculateProgressEstimation(_totalTimeMillis, _estimatedTimeMillis!);
      _deviation = _progressEstimation - 100;
    }
  }

  /// Calcula el tiempo transcurrido desde la última actualización del tiempo.
  ///
  /// Si [roundToSecond] es `true` el tiempo transcurrido se redondea al segundo más cercano.
  ///
  /// Devuelve el tiempo actual usado para calcular la diferencia y los milisegundos transcurridos.
  (DateTime now, int elapsedMillis) updateElapsedTime({
    bool roundToSecond = false,
  }) {
    final now = DateTime.now();
    final elapsed = now.difference(lastUpdated);
    int elapsedMillis;

    if (roundToSecond) {
      elapsedMillis = elapsed.roundToSecondMillis();
      _totalTimeMillis = DurationFormat.roundMillisToSecond(
        _totalTimeMillis + elapsedMillis,
      );
    } else {
      elapsedMillis = elapsed.inMilliseconds;
      _totalTimeMillis += elapsedMillis;
    }

    lastUpdated = now;

    _updateDeviation();

    log(
      enabled: true,
      'Elapsed: ${(elapsed.inMilliseconds / Duration.millisecondsPerSecond).toStringAsFixed(3)}'
      '  Now: ${now.formatTime()}'
      '  From: ${lastUpdated.formatTime()}'
      '  +${(elapsedMillis / Duration.millisecondsPerSecond).toStringAsFixed(3)}'
      '  Total: $totalTime (${totalTime.format()})',
    );

    return (now, elapsedMillis);
  }

  static double calculateProgressEstimation(int totalTime, int estimatedTime) {
    return estimatedTime == 0 ? 0.0 : (totalTime / estimatedTime) * 100;
  }

  static double calculateDeviation(int totalTime, int estimatedTime) {
    return estimatedTime == 0 ? 0.0 : ((totalTime / estimatedTime) - 1) * 100;
  }

  void update(Task other) {
    if (id != other.id)
      throw AssertionError(
        'Cannot update task $id from different task with id ${other.id}',
      );
    title = other.title;
    description = other.description;
    lastUpdated = other.lastUpdated;
    isRunning = other.isRunning;
    archived = other.archived;
    _estimatedTimeMillis = other.estimatedTimeMillis;
    _totalTimeMillis = other.totalTimeMillis;
    _updateDeviation();
    timeHistory.clear();
    timeHistory.addAll(other.timeHistory);
    setProject(other.project.value);
  }

  @override
  String toString() {
    return 'Task(id: $id, title: $title, isRunning: $isRunning, archived: $archived)';
  }
}
