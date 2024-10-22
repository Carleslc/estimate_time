import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../services/isar_service.dart';
import '../services/timer_service.dart';
import '../utils/date.dart';
import '../utils/message.dart';

class TaskProvider with ChangeNotifier {
  final IsarService isarService;
  final TimerService timerService = TimerService();

  List<Task> _tasks = [];
  List<Task> _archivedTasks = [];

  List<Task> get tasks => UnmodifiableListView(_tasks);
  List<Task> get archivedTasks => UnmodifiableListView(_archivedTasks);
  List<Task> get allTasks => [..._tasks, ..._archivedTasks];

  TaskProvider(this.isarService) {
    loadTasks(resumeTimers: true);
  }

  Future<void> loadTasks({bool resumeTimers = false}) async {
    await _loadActiveTasks();
    await _loadArchivedTasks();

    if (resumeTimers) {
      // Reanudar cronómetros para tareas que estaban corriendo antes de cerrar la app
      for (var task in _tasks) {
        if (task.isRunning) {
          _resumeTimer(task);
        }
      }
    }

    notifyListeners();
  }

  Future<void> _loadActiveTasks() async {
    final isar = await isarService.db;
    _tasks = await isar.tasks.filter().archivedEqualTo(false).findAll();
  }

  Future<void> _loadArchivedTasks() async {
    final isar = await isarService.db;
    _archivedTasks = await isar.tasks.filter().archivedEqualTo(true).findAll();
  }

  Future<Task> createTask(
    String title,
    Project? project,
    Duration? estimatedTime,
  ) async {
    final task = Task()
      ..title = title
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
    final isar = await isarService.db;
    await isar.writeTxn(() async {
      await isar.tasks.update(task);
    });
    if (notify) notifyListeners();
  }

  void startTimer(Task task) {
    if (task.isRunning) return;

    _runTimer(task);
  }

  void _runTimer(Task task) {
    if (timerService.isRunning(task.id)) return;

    // Inicia el cronómetro
    timerService.startTimer(task.id, () {
      final elapsed = task.updateElapsedTime();
      _updateTimeHistory(task, elapsed);
      notifyListeners();
    });

    task.isRunning = true;
    task.lastUpdated = DateTime.now();

    updateTask(task);
  }

  void _resumeTimer(Task task) {
    final elapsed = task.updateElapsedTime();

    // Actualizar historial
    _updateTimeHistory(task, elapsed);

    // Calcular desviación
    task.updateDeviation();

    // Inicia el cronómetro
    _runTimer(task);
  }

  Future<void> pauseTimer(Task task, {bool notify = true}) async {
    if (!task.isRunning) return;

    final elapsed = task.updateElapsedTime();

    // Pausar el cronómetro
    timerService.stopTimer(task.id);

    task.isRunning = false;

    // Actualizar historial
    await _updateTimeHistory(task, elapsed);

    // Calcular desviación
    task.updateDeviation();

    await updateTask(task, notify: notify);
  }

  Future<void> toggleTaskTimer(Task task) async {
    if (task.isRunning) {
      await pauseTimer(task);
    } else {
      startTimer(task);
    }
  }

  Future<void> _updateTimeHistory(Task task, Duration elapsed) async {
    final isar = await isarService.db;
    await task.timeHistory.load();

    final now = DateTime.now();

    await isar.writeTxn(() async {
      TimeEntry? timeEntry;

      // TODO: Reverse iteration (recent entries are added last)
      for (TimeEntry entry in task.timeHistory) {
        if (isSameDay(entry.date, now)) {
          timeEntry = entry;
          break;
        }
      }

      if (timeEntry == null) {
        // Crear un nuevo TimeEntry
        timeEntry = TimeEntry()
          ..date = now
          ..milliseconds = elapsed.inMilliseconds;
        // Añadir el nuevo TimeEntry
        await isar.timeEntries.put(timeEntry);
        task.timeHistory.add(timeEntry);
        await isar.tasks.put(task);
      } else {
        // Actualizar el TimeEntry existente
        timeEntry.milliseconds += elapsed.inMilliseconds;
        await isar.timeEntries.put(timeEntry);
      }
      await task.timeHistory.save();
    });
  }

  Future<void> archiveTask(BuildContext context, Task task) {
    return tryOrShowError(context, () async {
      // Pausa el cronómetro antes de archivar la tarea
      await pauseTimer(task, notify: false);

      // Archiva la tarea
      task.archived = true;
      await updateTask(task, notify: false);

      // Actualiza la lista de tareas
      _tasks.remove(task);
      await _loadArchivedTasks();

      notifyListeners();

      ShowMessage.taskArchived(context, task);
    }, 'No se ha podido archivar la tarea');
  }

  Future<void> unarchiveTask(BuildContext context, Task task) {
    return tryOrShowError(context, () async {
      // Desarchiva la tarea
      task.archived = false;
      await updateTask(task, notify: false);

      // Actualiza la lista de tareas
      _archivedTasks.remove(task);
      await _loadActiveTasks();

      notifyListeners();

      ShowMessage.taskUnarchived(context, task);
    }, 'No se ha podido desarchivar la tarea');
  }

  Future<void> deleteTask(BuildContext context, Task task) {
    return tryOrShowError(context, () async {
      Project? linkedProject = task.project.value;

      // Elimina la tarea (UI)
      _tasks.remove(task);
      _archivedTasks.remove(task);

      // Elimina la tarea (DB)
      final isar = await isarService.db;
      await isar.writeTxn(() async {
        await isar.tasks.delete(task.id);
      });

      notifyListeners();

      ShowMessage.taskDeleted(context, task, (deletedTask) async {
        await restoreTask(context, deletedTask, linkedProject);
      });
    }, 'No se ha podido eliminar la tarea');
  }

  Future<void> restoreTask(
    BuildContext context,
    Task task,
    Project? linkedProject,
  ) {
    return tryOrShowError(context, () async {
      // Restaurar la referencia al proyecto
      if (linkedProject != null) {
        final isar = await isarService.db;
        linkedProject = await isar.projects.get(linkedProject!.id);
        if (linkedProject != null) {
          task.project.value = linkedProject;
        }
      }
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
    timerService.stopAll();
    super.dispose();
  }
}

extension IsarTasksExtension on IsarCollection<Task> {
  /// Put task (insert or update) and save project link.
  ///
  /// Returns the id of the new or updated task.
  Future<int> update(Task task) async {
    int id = await isar.tasks.put(task);
    await task.project.save();
    return id;
  }
}
