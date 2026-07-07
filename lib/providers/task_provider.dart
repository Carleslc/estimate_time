import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

import '../models/chart_data.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../models/time_entry.dart';
import '../services/isar_service.dart';
import '../services/timer_service.dart';
import '../utils/date.dart';
import '../utils/duration.dart';
import '../utils/log.dart';
import '../utils/message.dart';

class TaskProvider with ChangeNotifier {
  final IsarService _isarService;
  final _timerService = TimerService(tickDuration: const Duration(seconds: 1));

  // Tareas activas y archivadas por ID
  final Map<Id, Task> _tasks = {};
  final Map<Id, Task> _archivedTasks = {};

  // Gráfico por ID de tarea
  final Map<Id, ChartData> _taskChartData = {};
  final Map<Id, StreamController<ChartData>> _taskChartControllers = {};

  // Cache (tasks)
  List<Task> _sortedTasks = [];
  bool _sortedTasksValid = false;

  /// Tareas activas
  List<Task> get tasks {
    if (!_sortedTasksValid) {
      _sortedTasks = UnmodifiableListView(
        _tasks.values.toList()..sort((a, b) => a.id.compareTo(b.id)),
      );
      _sortedTasksValid = true;
    }
    return _sortedTasks;
  }

  // Cache (archivedTasks)
  List<Task> _sortedArchivedTasks = [];
  bool _sortedArchivedTasksValid = false;

  /// Tareas archivadas
  List<Task> get archivedTasks {
    if (!_sortedArchivedTasksValid) {
      _sortedArchivedTasks = UnmodifiableListView(
        _archivedTasks.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)), // desc
      );
      _sortedArchivedTasksValid = true;
    }
    return _sortedArchivedTasks;
  }

  /// Todas las tareas
  List<Task> get allTasks => [...tasks, ...archivedTasks];

  TaskProvider(IsarService isarService) : _isarService = isarService {
    _loadTasks();
  }

  Future<void> loadTasks() async {
    await _loadTasks(resumeTimers: false);
  }

  Future<void> _loadTasks({bool resumeTimers = true}) async {
    await _loadActiveTasks();
    await _loadArchivedTasks();

    if (resumeTimers) {
      final List<Future> timerFutures = [];

      // Reanudar cronómetros para tareas que estaban corriendo
      for (Task task in _tasks.values) {
        if (task.isRunning) {
          timerFutures.add(_resumeTimer(task.id));
        }
      }

      // Espera a que todos los cronómetros empiecen
      await Future.wait(timerFutures);
    }

    notifyListeners();
  }

  Future<void> _loadActiveTasks() async {
    final isar = await _isarService.db;
    final dbActiveTasks =
        await isar.tasks.filter().archivedEqualTo(false).findAll();
    await _updateTasksList(_tasks, dbActiveTasks);
    _sortedTasksValid = false;
  }

  Future<void> loadActiveTasks() async {
    await _loadActiveTasks();
    notifyListeners();
  }

  Future<void> _loadArchivedTasks() async {
    final isar = await _isarService.db;
    final dbArchivedTasks =
        await isar.tasks.filter().archivedEqualTo(true).findAll();
    await _updateTasksList(_archivedTasks, dbArchivedTasks);
    _sortedArchivedTasksValid = false;
  }

  Future<void> loadArchivedTasks() async {
    await _loadArchivedTasks();
    notifyListeners();
  }

  Future<void> _updateTasksList(
    Map<Id, Task> tasks,
    final Iterable<Task> updatedTasks,
  ) async {
    final Set<Id> existingIds = {};

    // Actualizar tareas existentes y agregar nuevas
    for (Task task in updatedTasks) {
      existingIds.add(task.id);

      // Instancia de la tarea que se mantiene en memoria
      Task keptTask = task;

      if (tasks.containsKey(task.id)) {
        keptTask = tasks[task.id]!;
        keptTask.update(task);
      } else {
        tasks[task.id] = task;
      }

      // Inicializa el historial de tiempo y el gráfico
      await task.timeHistory.load();
      setTodayTime(keptTask);
      updateTaskChartData(task);
    }

    // Eliminar tareas que ya no existen
    tasks.removeWhere((id, task) => !existingIds.contains(id));
  }

  Future<Task> createTask(
    String title,
    String description,
    Project? project,
    Duration? estimatedTime,
  ) async {
    final task = Task()
      ..title = title
      ..description = description
      ..estimatedTime = estimatedTime
      ..lastUpdated = DateTime.now()
      ..setProject(project);

    await _addTask(task);

    notifyListeners();

    return task;
  }

  Future<void> _addTask(Task task) async {
    // Añadir tarea (DB)
    await updateTask(task);

    // Añadir tarea (UI)
    if (task.archived) {
      _archivedTasks[task.id] = task;
      _sortedArchivedTasksValid = false;
    } else {
      _tasks[task.id] = task;
      _sortedTasksValid = false;
    }

    log(enabled: true, 'Add Task: $task');
  }

  Future<void> updateTask(Task task, {bool notify = true}) async {
    final isar = await _isarService.db;
    await isar.writeTxn(() async {
      await isar.tasks.update(task);
    });
    if (notify) notifyListeners();
  }

  Future<void> startTimer(Task task) async {
    if (task.isRunning) return;

    // Inicia el cronómetro
    await _runTimer(task.id);
  }

  Future<void> _resumeTimer(Id taskId) async {
    // Actualizar tiempo y distribuir los días
    await _updateTimeDays(taskId);

    // Inicia el cronómetro
    await _runTimer(taskId);
  }

  Future<void> _runTimer(Id taskId) async {
    if (_timerService.isRunning(taskId)) return;

    final Task task = _getActiveTask(taskId);

    task.lastUpdated = DateTime.now();

    // Inicia el cronómetro
    _timerService.startTimer(
      taskId,
      syncTime: task.totalTime,
      onFirstTick: () {
        _updateTimeOnTick(taskId, roundToSecond: false);
      },
      onTick: () {
        _updateTimeOnTick(taskId, roundToSecond: true);
      },
    );

    // Actualiza el estado
    task.isRunning = true;

    await updateTask(task);
  }

  Future<void> pauseTimer(Task task) async {
    if (!task.isRunning) return;

    // Actualiza el estado
    task.isRunning = false;

    // Actualizar tiempo
    await _updateTime(task.id);

    // Pausa el cronómetro
    _timerService.stopTimer(task.id);

    notifyListeners();
  }

  Future<void> toggleTaskTimer(Task task) async {
    if (task.isRunning) {
      await pauseTimer(task);
    } else {
      await startTimer(task);
    }
  }

  Future<void> _updateTimeOnTick(
    Id taskId, {
    required bool roundToSecond,
  }) async {
    // Actualizar tiempo
    await _updateTime(taskId, roundToSecond: roundToSecond);

    // Actualizar UI
    notifyListeners();
  }

  Task? getTask(Id taskId) => _tasks[taskId] ?? _archivedTasks[taskId];

  Task _getActiveTask(Id taskId) {
    final Task? task = _tasks[taskId]; // obtener de las tareas activas

    if (task == null) {
      throw StateError('Task not found: $taskId');
    }

    return task;
  }

  Future<void> _updateTime(Id taskId, {bool roundToSecond = false}) async {
    final Task task = _getActiveTask(taskId);

    // Si ha cambiado el día desde la última actualización (al pasar la medianoche
    // o al reanudar los ticks tras suspender la app en segundo plano)
    // se distribuye el tiempo transcurrido entre los días correspondientes
    if (!task.lastUpdated.isSameDay(DateTime.now())) {
      return _updateTimeDays(taskId, roundToSecond: roundToSecond);
    }

    // Actualizar tiempo
    final (DateTime now, int elapsedMillis) =
        task.updateElapsedTime(roundToSecond: roundToSecond);

    // Actualizar historial de tiempo
    await _updateTimeEntry(task, now, elapsedMillis, roundToSecond);
  }

  Future<void> _updateTimeDays(Id taskId, {bool roundToSecond = false}) async {
    final Task task = _getActiveTask(taskId);

    // Última fecha actualizada
    DateTime lastDateTime = task.lastUpdated;

    // Actualizar tiempo
    final (DateTime now, int totalElapsedMillis) =
        task.updateElapsedTime(roundToSecond: roundToSecond);

    // Reloj del sistema atrasado ?
    final bool reverse = now.isBefore(lastDateTime);

    // Tiempo a distribuir
    int remainingElapsedMillis = totalElapsedMillis;

    // Último día actualizado
    DateTime startOfDay = lastDateTime.toDate();

    // Actualizar historial de tiempo para los días anteriores
    while (!startOfDay.isSameDay(now)) {
      // Inicio del día siguiente
      final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      // Calcula el tiempo transcurrido en ese día
      // lastDateTime <= now: +(endOfDay - lastDateTime)
      // now < lastDateTime (reverse): -(lastDateTime - startOfDay)
      Duration elapsedDayTime =
          (reverse ? startOfDay : endOfDay).difference(lastDateTime);

      int elapsedDayMillis = elapsedDayTime.inMilliseconds;

      // Actualiza el tiempo de ese día
      await _updateTimeEntry(
        task,
        startOfDay,
        elapsedDayMillis,
        roundToSecond,
      );

      // Resta el tiempo actualizado de este día al tiempo restante
      remainingElapsedMillis -= elapsedDayMillis;

      // Avanza o retrocede la fecha a actualizar
      lastDateTime = reverse ? startOfDay : endOfDay;

      // Inicio del siguiente día a actualizar
      startOfDay = reverse
          ? lastDateTime.subtract(const Duration(days: 1))
          : lastDateTime;
    }

    // Actualizar historial de tiempo para el día actual
    await _updateTimeEntry(
      task,
      startOfDay,
      remainingElapsedMillis,
      roundToSecond,
    );
  }

  Future<void> _updateTimeEntry(
    Task task,
    DateTime timestamp,
    int elapsedMillis,
    bool roundToSecond,
  ) async {
    await task.timeHistory.load();

    TimeEntry? timeEntry = task.todayTimeEntry ?? task.lastTimeEntry;

    bool isFirst = timeEntry == null;

    bool isNew = isFirst || !timeEntry.date.isSameDay(timestamp);

    if (isNew) {
      // Crear un nuevo TimeEntry
      timeEntry = TimeEntry.ofMillis(
        isFirst ? timestamp : timestamp.toDate(),
        elapsedMillis,
      );
    } else {
      // Actualizar el TimeEntry existente
      timeEntry.milliseconds += elapsedMillis;
    }

    if (roundToSecond) {
      timeEntry.milliseconds = DurationFormat.roundMillisToSecond(
        timeEntry.milliseconds,
      );
    }

    // Actualizar todayTime
    task.todayTimeEntry = timeEntry;

    // Actualizar el TimeEntry (DB)
    await _setTimeEntry(task, timeEntry, add: isNew);
  }

  Future<void> setTodayTimeDuration(Task task, Duration duration) async {
    await task.timeHistory.load();

    TimeEntry? timeEntry = task.todayTimeEntry ?? task.lastTimeEntry;

    final now = DateTime.now();

    bool isToday = timeEntry != null && timeEntry.date.isSameDay(now);

    if (isToday) {
      final int elapsedMillis = duration.inMilliseconds;

      // Actualizar tiempo
      task.totalTimeMillis += elapsedMillis - timeEntry.milliseconds;
      task.lastUpdated = now;

      // Actualizar todayTime
      timeEntry.milliseconds = elapsedMillis;
      task.todayTimeEntry = timeEntry;

      // Actualizar el TimeEntry (DB)
      await _setTimeEntry(task, timeEntry);

      notifyListeners();
    }
  }

  Future<void> _setTimeEntry(
    Task task,
    TimeEntry timeEntry, {
    bool add = false,
  }) async {
    final isar = await _isarService.db;

    await isar.writeTxn(() async {
      // Actualizar el TimeEntry
      await isar.timeEntries.put(timeEntry);

      // Añade el TimeEntry
      if (add) {
        task.timeHistory.add(timeEntry);
        log(enabled: true, 'New: ${task.timeHistory.lastOrNull}, $task');
        // Añade al gráfico
        _addTimeEntryChart(task, timeEntry);
      } else {
        log(enabled: false, 'Update: $timeEntry');
        // Actualizar el gráfico
        _updateLastChartPoint(task, timeEntry);
      }

      // Actualizar historial
      await task.timeHistory.save();

      // Actualizar tarea
      await isar.tasks.put(task);
    });
  }

  /// Añade un TimeEntry al gráfico de una tarea
  void _addTimeEntryChart(Task task, TimeEntry timeEntry) {
    // Filtrar la última semana
    final now = DateTime.now();
    if (timeEntry.day.isAfter(now.subtract(const Duration(days: 7)))) {
      final chartData = getChartDataForTask(task.id);
      if (chartData != null) {
        chartData.points.add(ChartPoint(
          dayIndex: chartData.points.length,
          minutes: timeEntry.duration.totalMinutes,
        ));
        chartData.labels.add(ChartLabel(
          label: '${timeEntry.date.day}/${timeEntry.date.month}',
          value: timeEntry.day,
        ));
        // Emitir los nuevos datos
        _emitChartData(task.id);
      }
    }
  }

  /// Actualiza solo el último punto del gráfico de una tarea
  void _updateLastChartPoint(Task task, TimeEntry timeEntry) {
    final chartData = getChartDataForTask(task.id);
    if (chartData != null && chartData.points.isNotEmpty) {
      final lastPoint = chartData.points.last;
      lastPoint.minutes = timeEntry.duration.totalMinutes;
      // Emitir los nuevos datos
      _emitChartData(task.id);
    }
  }

  /// Actualiza los datos del gráfico de una tarea
  void updateTaskChartData(final Task task) {
    // Filtrar la última semana
    final now = DateTime.now();
    final lastWeek = now.subtract(const Duration(days: 7));
    final recentEntries = task.timeHistory
        .toList()
        .where((timeEntry) => timeEntry.day.isAfter(lastWeek))
        .toList();

    // Ordenar por fecha
    recentEntries.sort();

    // Preparar etiquetas y datos
    final labels = recentEntries.map((e) {
      return ChartLabel(label: '${e.date.day}/${e.date.month}', value: e.day);
    }).toList();

    final points =
        recentEntries.asMap().entries.map((MapEntry<int, TimeEntry> e) {
      return ChartPoint(
        dayIndex: e.key,
        minutes: e.value.duration.totalMinutes,
      );
    }).toList();

    // Emitir datos del gráfico
    _taskChartData[task.id] = ChartData(
      points: points,
      labels: labels,
    );
    _emitChartData(task.id);

    log(
      enabled: false,
      '${task.title} updateTaskChartData ${DateTime.now()}',
    );
  }

  /// Obtén los datos del gráfico de una tarea
  ChartData? getChartDataForTask(Id taskId) {
    return _taskChartData[taskId];
  }

  /// Stream de los datos del gráfico
  Stream<ChartData> getChartDataStream(Id taskId) {
    if (!_taskChartControllers.containsKey(taskId)) {
      _emitChartData(taskId);
    }
    return _taskChartControllers[taskId]!.stream;
  }

  void _emitChartData(Id taskId) {
    // Crear el StreamController si es necesario
    if (!_taskChartControllers.containsKey(taskId)) {
      _taskChartControllers[taskId] = StreamController<ChartData>.broadcast();
    }
    // Emitir los datos actuales
    if (_taskChartData.containsKey(taskId)) {
      _taskChartControllers[taskId]!.add(_taskChartData[taskId]!);
    }
  }

  void setTodayTime(Task task) {
    final DateTime now = DateTime.now();

    if (task.todayTimeEntry != null &&
        task.todayTimeEntry!.date.isSameDay(now)) {
      return;
    }

    TimeEntry? lastTimeEntry = task.lastTimeEntry;

    // Actualiza todayTime, invalidándolo si es de un día anterior
    task.todayTimeEntry =
        lastTimeEntry != null && lastTimeEntry.date.isSameDay(now)
            ? lastTimeEntry
            : null;
  }

  Future<void> archiveTask(Task task) {
    return tryOrShowError(() async {
      // Pausa el cronómetro antes de archivar la tarea
      await pauseTimer(task);

      // Archiva la tarea (UI)
      task.archived = true;

      _tasks.remove(task.id);
      _archivedTasks[task.id] = task;

      // Invalida la caché
      _sortedTasksValid = false;
      _sortedArchivedTasksValid = false;

      notifyListeners();

      // Archiva la tarea (DB)
      await updateTask(task, notify: false);

      // Actualiza la lista de tareas (archived)
      await _loadArchivedTasks();

      notifyListeners();

      ShowMessage.taskArchived(task);
    }, 'No se ha podido archivar la tarea');
  }

  Future<void> unarchiveTask(Task task) {
    return tryOrShowError(() async {
      // Desarchiva la tarea (UI)
      task.archived = false;

      _archivedTasks.remove(task.id);
      _tasks[task.id] = task;

      // Invalida la caché
      _sortedTasksValid = false;
      _sortedArchivedTasksValid = false;

      notifyListeners();

      // Desarchiva la tarea (DB)
      await updateTask(task, notify: false);

      // Actualiza la lista de tareas (active)
      await _loadActiveTasks();

      notifyListeners();

      ShowMessage.taskUnarchived(task);
    }, 'No se ha podido desarchivar la tarea');
  }

  Future<void> deleteTask(Task task) {
    return tryOrShowError(() async {
      Project? linkedProject = task.project.value;
      List<TimeEntry> timeHistory = task.timeHistory.toList();

      // Pausa el cronómetro
      await pauseTimer(task);

      // Elimina la tarea (UI)
      final removedActive = _tasks.remove(task.id);
      final removedArchived = _archivedTasks.remove(task.id);

      // Invalida la caché
      _sortedTasksValid = removedActive == null;
      _sortedArchivedTasksValid = removedArchived == null;

      notifyListeners();

      // Elimina la tarea (DB)
      final isar = await _isarService.db;
      await isar.writeTxn(() async {
        // Historial de tiempo
        await isar.timeEntries
            .deleteAll(timeHistory.map((timeEntry) => timeEntry.id).toList());
        // Tarea
        await isar.tasks.delete(task.id);
      });

      // Actualiza la lista de tareas
      await loadTasks();

      ShowMessage.taskDeleted(task, (deletedTask) async {
        await restoreTask(deletedTask, linkedProject, timeHistory);
      });
    }, 'No se ha podido eliminar la tarea');
  }

  Future<void> restoreTask(
    final Task task,
    final Project? linkedProject,
    final List<TimeEntry> timeHistory,
  ) {
    return tryOrShowError(() async {
      // Restaurar la tarea (DB)
      await updateTask(task, notify: false);

      // Obtener la instancia restaurada de la tarea
      final isar = await _isarService.db;
      final restoredTask = await isar.tasks.get(task.id);
      if (restoredTask == null) {
        throw StateError('La tarea no se pudo restaurar');
      }

      // Restaurar la referencia al proyecto
      if (linkedProject != null) {
        final Project? linkedProjectInstance =
            await isar.projects.get(linkedProject.id);
        if (linkedProjectInstance != null) {
          restoredTask.project.value = linkedProjectInstance;
        }
      }

      // Restaurar las referencias de tiempo
      await isar.writeTxn(() async {
        restoredTask.timeHistory.clear();

        for (TimeEntry timeEntry in timeHistory) {
          await isar.timeEntries.put(timeEntry);
          timeEntry.task.value = restoredTask;
          await timeEntry.task.save();
        }

        restoredTask.timeHistory.addAll(timeHistory);
        await restoredTask.timeHistory.update(link: timeHistory);

        await isar.tasks.saveLinks(restoredTask);
      });

      // Actualiza la lista de tareas
      await loadTasks();

      ShowMessage.taskRestored(task);
    }, 'No se ha podido restaurar la tarea');
  }

  Future<Task?> copyTask(Task task) async {
    return tryOrShowError(() async {
      final newTask = await createTask(
        task.title,
        task.description,
        task.project.value,
        task.estimatedTime,
      );

      ShowMessage.taskCopied(newTask);

      return newTask;
    }, 'No se ha podido copiar la tarea');
  }

  /// Detener todos los cronómetros y cerrar los streams al destruir el provider
  @override
  void dispose() {
    _timerService.stopAll();
    _taskChartControllers.forEach((taskId, controller) => controller.close());
    super.dispose();
  }
}

extension IsarTasksExtension on IsarCollection<Task> {
  /// Put task (insert or update) and save links.
  ///
  /// Returns the id of the new or updated task.
  Future<int> update(final Task task) async {
    int id = await isar.tasks.put(task);
    await isar.tasks.saveLinks(task);
    return id;
  }

  /// Save task links (project, timeHistory)
  Future<void> saveLinks(final Task task) async {
    await task.project.save();
    await task.timeHistory.save();
  }
}
