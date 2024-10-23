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
import '../utils/log.dart';
import '../utils/message.dart';

class TaskProvider with ChangeNotifier {
  final IsarService _isarService;
  final TimerService _timerService = TimerService();

  List<Task> _tasks = [];
  List<Task> _archivedTasks = [];

  List<Task> get tasks => UnmodifiableListView(_tasks);
  List<Task> get archivedTasks => UnmodifiableListView(_archivedTasks);
  List<Task> get allTasks => [..._tasks, ..._archivedTasks];

  TaskProvider(IsarService isarService) : _isarService = isarService {
    _loadTasks();
  }

  Future<void> _loadTasks({bool resumeTimers = true}) async {
    await _loadActiveTasks();
    await _loadArchivedTasks();

    if (resumeTimers) {
      final List<Future> _timers = [];

      // Reanudar cronómetros para tareas que estaban corriendo
      for (var task in _tasks) {
        if (task.isRunning) {
          _timers.add(_resumeTimer(task));
        }
      }

      // Espera a que todos los cronómetros empiecen
      await Future.wait(_timers);
    }

    notifyListeners();
  }

  Future<void> loadTasks() async {
    _loadTasks(resumeTimers: false);
  }

  Future<void> _loadActiveTasks() async {
    final isar = await _isarService.db;
    _tasks = await isar.tasks.filter().archivedEqualTo(false).findAll();
  }

  Future<void> loadActiveTasks() async {
    await _loadActiveTasks();
    notifyListeners();
  }

  Future<void> _loadArchivedTasks() async {
    final isar = await _isarService.db;
    _archivedTasks = await isar.tasks.filter().archivedEqualTo(true).findAll();
  }

  Future<void> loadArchivedTasks() async {
    await _loadArchivedTasks();
    notifyListeners();
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
    // Añadir tarea (UI)
    if (task.archived) {
      _archivedTasks.add(task);
    } else {
      _tasks.add(task);
    }
    // Añadir tarea (DB)
    await updateTask(task);
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
    await _runTimer(task);
  }

  Future<void> _resumeTimer(Task task) async {
    // Actualizar tiempo
    await _updateTime(task);

    // Inicia el cronómetro
    await _runTimer(task);
  }

  Future<void> _runTimer(Task task) async {
    if (_timerService.isRunning(task.id)) return;

    task.isRunning = true;
    task.lastUpdated = DateTime.now();

    // Inicia el cronómetro
    _timerService.startTimer(task.id, () {
      _updateTimeUI(task);
    });

    await updateTask(task);
  }

  Future<void> pauseTimer(Task task) async {
    if (!task.isRunning) return;

    // Actualizar tiempo
    await _updateTime(task);

    // Pausa el cronómetro
    _timerService.stopTimer(task.id);

    // Actualiza el estado
    task.isRunning = false;

    await updateTask(task);
  }

  Future<void> toggleTaskTimer(Task task) async {
    if (task.isRunning) {
      await pauseTimer(task);
    } else {
      await startTimer(task);
    }
  }

  Future<void> _updateTimeUI(Task task) async {
    // Actualizar tiempo
    await _updateTime(task);

    // Actualizar UI
    notifyListeners();
  }

  Future<void> _updateTime(Task task) async {
    // Actualizar tiempo
    final (DateTime now, Duration elapsed) = task.updateElapsedTime();

    // Actualizar historial de tiempo
    await _updateTimeEntry(task, now, elapsed);
  }

  Future<void> _updateTimeEntry(
      Task task, DateTime now, Duration elapsed) async {
    final isar = await _isarService.db;
    await task.timeHistory.load();

    await isar.writeTxn(() async {
      TimeEntry? timeEntry = task.todayTimeEntry ?? task.lastTimeEntry;

      if (timeEntry == null || !timeEntry.date.isSameDay(now)) {
        // Crear un nuevo TimeEntry
        timeEntry = TimeEntry()
          ..date = now
          ..milliseconds = elapsed.inMilliseconds;
        // Añadir el nuevo TimeEntry
        await isar.timeEntries.put(timeEntry);
        task.timeHistory.add(timeEntry);
        log('New: ${task.timeHistory.lastOrNull}, $task');
      } else {
        // Actualizar el TimeEntry existente
        timeEntry.milliseconds += elapsed.inMilliseconds;
        await isar.timeEntries.put(timeEntry);
        log(enabled: false, 'Update: $timeEntry');
      }

      // Actualiza todayTime
      task.todayTimeEntry = timeEntry;

      // Actualizar historial (DB)
      await task.timeHistory.save();

      // Actualizar tarea (DB)
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

  Future<void> archiveTask(BuildContext context, Task task) {
    return tryOrShowError(context, () async {
      // Archiva la tarea (UI)
      _tasks.remove(task);

      // Pausa el cronómetro antes de archivar la tarea
      await pauseTimer(task);

      // Archiva la tarea (DB)
      task.archived = true;
      await updateTask(task, notify: false);

      // Actualiza la lista de tareas (archived)
      await _loadArchivedTasks();

      notifyListeners();

      ShowMessage.taskArchived(context, task);
    }, 'No se ha podido archivar la tarea');
  }

  Future<void> unarchiveTask(BuildContext context, Task task) {
    return tryOrShowError(context, () async {
      // Desarchiva la tarea (UI)
      _archivedTasks.remove(task);

      notifyListeners();

      // Desarchiva la tarea (DB)
      task.archived = false;
      await updateTask(task, notify: false);

      // Actualiza la lista de tareas (active)
      await _loadActiveTasks();

      notifyListeners();

      ShowMessage.taskUnarchived(context, task);
    }, 'No se ha podido desarchivar la tarea');
  }

  Future<void> deleteTask(BuildContext context, Task task) {
    return tryOrShowError(context, () async {
      Project? linkedProject = task.project.value;
      List<TimeEntry> timeHistory = task.timeHistory.toList();

      // Pausa el cronómetro
      await pauseTimer(task);

      // Elimina la tarea (UI)
      _tasks.remove(task);
      _archivedTasks.remove(task);

      notifyListeners();

      // Elimina la tarea (DB)
      final isar = await _isarService.db;
      await isar.writeTxn(() async {
        await isar.tasks.delete(task.id);
      });

      // TODO: Elimina los TimeEntry de timeHistory ? (view isar inspector)

      ShowMessage.taskDeleted(context, task, (deletedTask) async {
        await restoreTask(context, deletedTask, linkedProject, timeHistory);
      });
    }, 'No se ha podido eliminar la tarea');
  }

  Future<void> restoreTask(
    BuildContext context,
    Task task,
    Project? linkedProject,
    List<TimeEntry> timeHistory,
  ) {
    return tryOrShowError(context, () async {
      // Restaurar la referencia al proyecto
      final isar = await _isarService.db;
      if (linkedProject != null) {
        linkedProject = await isar.projects.get(linkedProject!.id);
        if (linkedProject != null) {
          task.project.value = linkedProject;
        }
      }

      // Restaurar las referencias de tiempo
      await isar.writeTxn(() async {
        task.timeHistory.addAll(timeHistory);
        await task.timeHistory.update(link: timeHistory);
      });

      // Restaurar la tarea (DB)
      await updateTask(task, notify: false);

      // Actualiza la lista de tareas
      loadTasks();
    }, 'No se ha podido restaurar la tarea');
  }

  Future<Task?> copyTask(BuildContext context, Task task) async {
    return tryOrShowError(context, () async {
      final newTask = await createTask(
        task.title,
        task.description,
        task.project.value,
        task.estimatedTime,
      );

      ShowMessage.taskCopied(context, newTask);

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
  Future<int> update(Task task) async {
    int id = await isar.tasks.put(task);
    await task.project.save();
    await task.timeHistory.save();
    return id;
  }
}
