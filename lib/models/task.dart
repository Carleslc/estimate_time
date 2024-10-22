import 'package:isar/isar.dart';

import 'project.dart';

part 'task.g.dart';

@Collection()
class Task {
  Id id = Isar.autoIncrement;

  late String title;

  // Referencia opcional al proyecto
  @Index()
  final project = IsarLink<Project>();

  // Tiempo estimado en milisegundos
  int? estimatedTimeMillis;

  // Tiempo total acumulado en milisegundos
  int totalTimeMillis = 0;

  // Tiempo registrado hoy en milisegundos
  int todayTimeMillis = 0;

  // Fecha de última actualización del tiempo registrado
  DateTime lastUpdated = DateTime.now();

  // Estado del cronómetro
  bool isRunning = false;

  // Desviación calculada (se actualiza al pausar)
  double deviation = 0.0;

  // Historial de tiempo por día
  final timeHistory = IsarLinks<TimeEntry>();

  // Estado de la tarea (activa / archivada)
  bool archived = false;

  // Propiedades calculadas para Duration
  @ignore
  Duration? get estimatedTime => estimatedTimeMillis != null
      ? Duration(milliseconds: estimatedTimeMillis!)
      : null;

  set estimatedTime(Duration? duration) {
    estimatedTimeMillis = duration?.inMilliseconds;
  }

  @ignore
  Duration get totalTime => Duration(milliseconds: totalTimeMillis);

  set totalTime(Duration duration) {
    totalTimeMillis = duration.inMilliseconds;
  }

  @ignore
  Duration get todayTime => Duration(milliseconds: todayTimeMillis);

  set todayTime(Duration duration) {
    todayTimeMillis = duration.inMilliseconds;
  }

  Future<Project?> getProject() async {
    if (project.value == null) return null;
    await project.load();
    Project? loadedProject = project.value;
    loadedProject?.update();
    return loadedProject;
  }

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

  void updateDeviation() {
    if (estimatedTimeMillis != null) {
      deviation = calculateDeviation(totalTimeMillis, estimatedTimeMillis!);
    }
  }

  Duration updateElapsedTime() {
    final now = DateTime.now();
    final elapsed = now.difference(lastUpdated);
    final elapsedMillis = elapsed.inMilliseconds;
    totalTimeMillis += elapsedMillis;
    todayTimeMillis += elapsedMillis;
    lastUpdated = now;
    return elapsed;
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
  Duration get duration => Duration(milliseconds: milliseconds);

  @ignore
  int get seconds => duration.inSeconds;

  @ignore
  DateTime get day => DateTime(date.year, date.month, date.day);

  @override
  String toString() => '$day: $duration';
}
