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

  // Tiempo estimado en segundos
  int? estimatedTimeSeconds;

  // Tiempo total acumulado en segundos
  int totalTimeSeconds = 0;

  // Tiempo registrado hoy en segundos
  int todayTimeSeconds = 0;

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
  Duration? get estimatedTime => estimatedTimeSeconds != null
      ? Duration(seconds: estimatedTimeSeconds!)
      : null;

  set estimatedTime(Duration? duration) {
    estimatedTimeSeconds = duration?.inSeconds;
  }

  @ignore
  Duration get totalTime => Duration(seconds: totalTimeSeconds);

  set totalTime(Duration duration) {
    totalTimeSeconds = duration.inSeconds;
  }

  @ignore
  Duration get todayTime => Duration(seconds: todayTimeSeconds);

  set todayTime(Duration duration) {
    todayTimeSeconds = duration.inSeconds;
  }

  Future<Project?> getProject() async {
    if (project.value == null) return null;
    await project.load();
    return project.value;
  }

  void setProject(Project? project) {
    this.project.value = project;
  }

  @ignore
  String get timerLabel {
    if (isRunning) {
      return 'Pausar';
    } else if (totalTimeSeconds > 0) {
      return 'Reanudar';
    } else {
      return 'Empezar';
    }
  }

  void updateDeviation() {
    if (estimatedTimeSeconds != null) {
      deviation = calculateDeviation(totalTimeSeconds, estimatedTimeSeconds!);
    }
  }

  Duration updateElapsedTime() {
    final now = DateTime.now();
    final elapsed = now.difference(lastUpdated);
    totalTime += elapsed;
    todayTime += elapsed;
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

  late int seconds; // Tiempo en segundos
}
