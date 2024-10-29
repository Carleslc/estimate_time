import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

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

  final Map<Id, Task> _tasks = {};
  final Map<Id, Task> _archivedTasks = {};

  List<Task> get tasks => UnmodifiableListView(_tasks.values);
  List<Task> get archivedTasks => UnmodifiableListView(_archivedTasks.values);
  List<Task> get allTasks => [..._tasks.values, ..._archivedTasks.values];

  TaskProvider(IsarService isarService) : _isarService = isarService {
    _loadTasks();
  }

  Future<void> loadTasks() async {
    _loadTasks(resumeTimers: false);
  }

  Future<void> _loadTasks({bool resumeTimers = true}) async {
    await _loadActiveTasks();
    await _loadArchivedTasks();

    if (resumeTimers) {
      final List<Future> _timerFutures = [];

      // Reanudar cronómetros para tareas que estaban corriendo
      for (Task task in _tasks.values) {
        if (task.isRunning) {
          _timerFutures.add(_resumeTimer(task.id));
        }
      }

      // Espera a que todos los cronómetros empiecen
      await Future.wait(_timerFutures);
    }

    notifyListeners();
  }

  Future<void> _loadActiveTasks() async {
    final isar = await _isarService.db;
    final dbActiveTasks =
        await isar.tasks.filter().archivedEqualTo(false).findAll();
    _updateTasksList(_tasks, dbActiveTasks);
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
  }

  Future<void> loadArchivedTasks() async {
    await _loadArchivedTasks();
    notifyListeners();
  }

  Future<void> _updateTasksList(
    Map<Id, Task> tasks,
    final List<Task> updatedTasks,
  ) async {
    final Set<Id> existingIds = {};

    // Actualizar tareas existentes y agregar nuevas
    for (Task task in updatedTasks) {
      existingIds.add(task.id);

      if (_tasks.containsKey(task.id)) {
        Task existingTask = tasks[task.id]!;
        existingTask.update(task);
      } else {
        tasks[task.id] = task;
      }

      await task.timeHistory.load();
      setTodayTime(task);
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

    return task;
  }

  Future<void> _addTask(Task task) async {
    // Añadir tarea (DB)
    await updateTask(task);

    // Añadir tarea (UI)
    if (task.archived) {
      _archivedTasks[task.id] = task;
    } else {
      _tasks[task.id] = task;
    }

    log('Add Task: $task');
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
    // Actualizar tiempo
    await _updateTime(taskId);

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

  Task _getActiveTask(Id taskId) {
    final Task? task = _tasks[taskId]; // obtener de las tareas activas

    if (task == null) {
      throw StateError('Task not found: $taskId');
    }

    return task;
  }

  Future<void> _updateTime(Id taskId, {bool roundToSecond = false}) async {
    final Task task = _getActiveTask(taskId);

    // Actualizar tiempo
    final (DateTime now, int elapsedMillis) =
        task.updateElapsedTime(roundToSecond: roundToSecond);

    // Actualizar historial de tiempo
    await _updateTimeEntry(task, now, elapsedMillis, roundToSecond);
  }

  Future<void> _updateTimeEntry(
    Task task,
    DateTime now,
    int elapsedMillis,
    bool roundToSecond,
  ) async {
    await task.timeHistory.load();

    TimeEntry? timeEntry = task.todayTimeEntry ?? task.lastTimeEntry;

    bool isNew = timeEntry == null || !timeEntry.date.isSameDay(now);

    if (isNew) {
      // Crear un nuevo TimeEntry
      timeEntry = TimeEntry()
        ..date = now
        ..milliseconds = elapsedMillis;
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
        log('New: ${task.timeHistory.lastOrNull}, $task');
      } else {
        log(enabled: true, 'Update: $timeEntry');
      }

      // Actualizar historial
      await task.timeHistory.save();

      // Actualizar tarea
      await isar.tasks.put(task);
    });
  }

  void setTodayTime(Task task) {
    if (task.todayTimeEntry != null) return;

    TimeEntry? lastTimeEntry = task.lastTimeEntry;

    if (lastTimeEntry != null && lastTimeEntry.date.isSameDay(DateTime.now())) {
      // Actualiza todayTime
      task.todayTimeEntry = lastTimeEntry;
    }
  }

  Future<void> archiveTask(Task task) {
    return tryOrShowError(() async {
      // Pausa el cronómetro antes de archivar la tarea
      await pauseTimer(task);

      // Archiva la tarea (UI)
      task.archived = true;

      _tasks.remove(task.id);
      _archivedTasks[task.id] = task;

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
      _tasks.remove(task.id);
      _archivedTasks.remove(task.id);

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

  // Detener todos los cronómetros al destruir el provider
  @override
  void dispose() {
    log('TaskProvider dispose()');
    _timerService.stopAll();
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
