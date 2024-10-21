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
    loadTasks();
  }

  Future<void> loadTasks() async {
    final isar = await isarService.db;
    _tasks = await isar.tasks.filter().archivedEqualTo(false).findAll();
    _archivedTasks = await isar.tasks.filter().archivedEqualTo(true).findAll();

    // Reanudar cronómetros para tareas que estaban corriendo antes de cerrar la app
    for (var task in _tasks) {
      if (task.isRunning) {
        _resumeTimer(task);
      }
    }
    notifyListeners();
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

    notifyListeners();

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
    final isar = await isarService.db;
    await isar.writeTxn(() async {
      await isar.tasks.put(task);
      await task.project.save();
    });
  }

  Future<void> updateTask(Task task, {bool notify = true}) async {
    final isar = await isarService.db;
    await isar.writeTxn(() async {
      await isar.tasks.put(task);
    });
    if (notify) notifyListeners();
  }

  void startTimer(Task task) {
    if (task.isRunning) return;

    // Inicia el cronómetro
    _runTimer(task);
  }

  // FIXME: Va muy lento sumando segundos. No se actualizan los segundos correctamente,
  // a veces tarda 2 o 3 segundos en actualizarse la UI y solo se suma un segundo,
  // así que esperando 10 segundos con el cronómetro en marcha a lo mejor se registran solo 6 o 7.
  // Sin embargo, el debugPrint se muestra aproximadamente cada segundo
  void _runTimer(Task task) {
    timerService.startTimer(task.id, () {
      final elapsed = task.updateElapsedTime();
      _updateTimeHistory(task, elapsed);
      debugPrint(elapsed.inMilliseconds.toString());
      notifyListeners();
    });

    task.isRunning = true;
    task.lastUpdated = DateTime.now();

    updateTask(task);
  }

  void _resumeTimer(Task task) {
    if (timerService.isRunning(task.id)) return;

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

    // Pausar el cronómetro
    timerService.stopTimer(task.id);

    task.isRunning = false;

    final elapsed = task.updateElapsedTime();

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
          ..seconds = elapsed.inSeconds;
        // Añadir el nuevo TimeEntry
        await isar.timeEntries.put(timeEntry);
        task.timeHistory.add(timeEntry);
        await isar.tasks.put(task);
      } else {
        // Actualizar el TimeEntry existente
        timeEntry.seconds += elapsed.inSeconds;
        await isar.timeEntries.put(timeEntry);
      }
    });
  }

  Future<void> archiveTask(BuildContext context, Task task) async {
    // Pausa el cronómetro antes de archivar la tarea
    await pauseTimer(task, notify: false);

    // Mueve la tarea a la lista de tareas archivadas (UI)
    task.archived = true;
    _tasks.remove(task);
    _archivedTasks.add(task);

    // Actualiza la tarea (DB)
    await updateTask(task);

    ShowMessage.taskArchived(context, task);
  }

  Future<void> unarchiveTask(BuildContext context, Task task) async {
    // Mueve la tarea a la lista de tareas activas (UI)
    task.archived = false;
    _archivedTasks.remove(task);
    _tasks.add(task);

    // Actualiza la tarea (DB)
    await updateTask(task);

    ShowMessage.taskUnarchived(context, task);
  }

  Future<void> deleteTask(BuildContext context, Task task) async {
    debugPrint('Before delete project: ${task.project.value}');

    // Elimina la tarea (UI)
    _tasks.remove(task);
    _archivedTasks.remove(task);

    // Elimina la tarea (DB)
    final isar = await isarService.db;
    await isar.writeTxn(() async {
      await isar.tasks.delete(task.id);
    });

    notifyListeners();

    debugPrint('After delete project: ${task.project.value}');

    ShowMessage.taskDeleted(context, task, restoreTask);
  }

  Future<void> restoreTask(Task task) async {
    debugPrint('Before restore project: ${task.project.value}');

    // Restaura la tarea
    await _addTask(task);

    // Asegurarse de que el proyecto está restaurado y vinculado
    if (task.project.value != null) {
      final project = await task.getProject();
      if (project != null) {
        await updateTask(task, notify: false);
      }
    }

    notifyListeners();

    debugPrint('After restore project: ${task.project.value}');
  }

  Future<Task> copyTask(BuildContext context, Task task) async {
    final newTask = await createTask(
      task.title,
      task.project.value,
      task.estimatedTime,
    );

    ShowMessage.taskCopied(context, newTask);

    return newTask;
  }

  // Detener todos los cronómetros al destruir el provider
  @override
  void dispose() {
    timerService.stopAll();
    super.dispose();
  }
}
