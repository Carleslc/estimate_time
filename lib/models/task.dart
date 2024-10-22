import 'package:isar/isar.dart';

import 'project.dart';

part 'task.g.dart';

@Collection()
class Task {
  Id id = Isar.autoIncrement;

  /// Título de la tarea
  late String title;

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
  Duration? get estimatedTime => estimatedTimeMillis != null
      ? Duration(milliseconds: estimatedTimeMillis!)
      : null;

  set estimatedTime(Duration? duration) {
    estimatedTimeMillis = duration?.inMilliseconds;
  }

  /// Tiempo total acumulado
  @ignore
  Duration get totalTime => Duration(milliseconds: totalTimeMillis);

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
    } else if (totalTimeMillis > 0) {
      return 'Reanudar';
    } else {
      return 'Empezar';
    }
  }

  /// Calcular desviación
  void _updateDeviation() {
    if (estimatedTimeMillis != null) {
      _progressEstimation =
          calculateProgressEstimation(totalTimeMillis, estimatedTimeMillis!);
      _deviation = _progressEstimation - 100;
    }
  }

  /// Calcular tiempo transcurrido desde la última actualización del tiempo
  (DateTime now, Duration elapsed) updateElapsedTime() {
    final now = DateTime.now();
    final elapsed = now.difference(lastUpdated);
    totalTimeMillis += elapsed.inMilliseconds;
    lastUpdated = now;
    return (now, elapsed);
  }

  static double calculateProgressEstimation(int totalTime, int estimatedTime) {
    return estimatedTime == 0 ? 0.0 : (totalTime / estimatedTime) * 100;
  }

  static double calculateDeviation(int totalTime, int estimatedTime) {
    return estimatedTime == 0 ? 0.0 : ((totalTime / estimatedTime) - 1) * 100;
  }
}

@Collection(accessor: 'timeEntries')
class TimeEntry {
  Id id = Isar.autoIncrement;

  late DateTime date;

  late int milliseconds;

  @ignore
  int get seconds => duration.inSeconds;

  @ignore
  Duration get duration => Duration(milliseconds: milliseconds);

  @ignore
  DateTime get day => DateTime(date.year, date.month, date.day);

  @override
  String toString() => '$day: $duration';
}
