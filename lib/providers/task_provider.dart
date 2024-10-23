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

// FIXME: A veces no cuadra el tiempo de la barra con el totalTime.
// No sé si tiene que ver con los reinicios.

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
      final List<Future> _timers = [];

      // Reanudar cronómetros para tareas que estaban corriendo antes de cerrar la app
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

  Future<void> startTimer(Task task) async {
    if (task.isRunning) return;

    await _runTimer(task);
  }

  Future<void> _runTimer(Task task) async {
    if (timerService.isRunning(task.id)) return;

    task.isRunning = true;
    task.lastUpdated = DateTime.now();

    await updateTask(task);

    // Inicia el cronómetro
    timerService.startTimer(task.id, () async {
      await _updateTime(task);
      notifyListeners();
    });
  }

  Future<void> _resumeTimer(Task task) async {
    // Actualizar tiempo
    await _updateTime(task);

    // Inicia el cronómetro
    await _runTimer(task);
  }

  Future<void> pauseTimer(Task task) async {
    if (!task.isRunning) return;

    // Pausa el cronómetro
    timerService.stopTimer(task.id);

    // Actualizar historial
    await _updateTime(task);

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

  Future<void> _updateTime(Task task) async {
    // Actualizar tiempo
    final (now, elapsed) = task.updateElapsedTime();

    // Actualizar historial de tiempo
    final isar = await isarService.db;
    await task.timeHistory.load();

    await isar.writeTxn(() async {
      TimeEntry? timeEntry = task.todayTimeEntry ?? task.lastTimeEntry;

      if (timeEntry == null || !timeEntry.date.isSameDay(now)) {
        // Crear un nuevo TimeEntry
        timeEntry = TimeEntry()
          ..date = now
          ..milliseconds = elapsed.inMilliseconds;
        // Añadir el nuevo TimeEntry
        task.todayTimeEntry = timeEntry;
        await isar.timeEntries.put(timeEntry);
        task.timeHistory.add(timeEntry);
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

      // Pausa el cronómetro
      await pauseTimer(task);

      // Elimina la tarea (UI)
      _tasks.remove(task);
      _archivedTasks.remove(task);

      notifyListeners();

      // Elimina la tarea (DB)
      final isar = await isarService.db;
      await isar.writeTxn(() async {
        await isar.tasks.delete(task.id);
      });

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
