import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

import '../models/chart_data.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../models/time_entry.dart';
import '../services/isar_service.dart';
import '../utils/duration.dart';
import '../utils/message.dart';
import 'task_provider.dart';

class ProjectProvider with ChangeNotifier {
  final IsarService _isarService;

  List<Project> _projects = [];

  List<Project> get projects => UnmodifiableListView(_projects);

  // Mapa para gestionar proyectos eliminados y sus tareas vinculadas
  final Map<int, List<Task>> _deletedProjectTasks = {};

  // Gráfico por ID de proyecto
  final Map<Id, ChartData> _projectChartData = {};
  final Map<Id, StreamController<ChartData>> _projectChartControllers = {};

  ProjectProvider(IsarService isarService) : _isarService = isarService {
    loadProjects();
  }

  Future<void> loadProjects() async {
    final isar = await _isarService.db;
    _projects = await isar.projects.where().findAll();
    notifyListeners();
  }

  Future<Project> createProject(String name, Color color) async {
    final project = Project()
      ..name = name
      ..color = color;

    await _addProject(project);

    return project;
  }

  Future<void> _addProject(Project project) async {
    _projects.add(project); // UI
    await updateProject(project); // DB
  }

  Future<void> updateProject(Project project, {bool notify = true}) async {
    final isar = await _isarService.db;
    await isar.writeTxn(() async {
      await isar.projects.put(project);
    });
    if (notify) notifyListeners();
  }

  Future<void> deleteProject(Project project, {VoidCallback? onRestored}) {
    return tryOrShowError(() async {
      // Elimina el proyecto (UI)
      _projects.remove(project);

      notifyListeners();

      final isar = await _isarService.db;

      // Encontrar tareas vinculadas al proyecto
      final List<Task> linkedTasks = await isar.tasks
          .filter()
          .project((q) => q.idEqualTo(project.id))
          .findAll();

      // Guardar las tareas vinculadas
      _deletedProjectTasks[project.id] = linkedTasks;

      await isar.writeTxn(() async {
        // Desvincular tareas del proyecto
        for (Task task in linkedTasks) {
          task.project.value = null;
          await isar.tasks.update(task);
        }
        // Elimina el proyecto (DB)
        await isar.projects.delete(project.id);
      });

      // Actualiza la lista de proyectos
      await loadProjects();

      // Actualizar datos del gráfico del proyecto
      updateProjectChartData(project);

      ShowMessage.projectDeleted(
        project,
        (deletedProject) async {
          await restoreProject(deletedProject);
          onRestored?.call();
        },
      )?.closed.then((SnackBarClosedReason reason) {
        if (reason != SnackBarClosedReason.action) {
          // Proyecto permanentemente eliminado
          _freeProject(project);
        }
      });
    }, 'No se ha podido eliminar el proyecto');
  }

  Future<void> restoreProject(final Project project) async {
    return tryOrShowError(() async {
      // Restaurar el proyecto
      await updateProject(project, notify: false); // DB

      // Obtener la instancia restaurada del proyecto
      final isar = await _isarService.db;
      final restoredProject = await isar.projects.get(project.id);
      if (restoredProject == null) {
        throw StateError('El proyecto no se pudo restaurar');
      }

      // Volver a vincular las tareas que estaban vinculadas antes de eliminar el proyecto
      final List<Task>? tasks = _deletedProjectTasks[project.id];

      if (tasks != null && tasks.isNotEmpty) {
        await isar.writeTxn(() async {
          for (Task task in tasks) {
            task.project.value = restoredProject;
            await isar.tasks.saveLinks(task);
          }
        });

        // Actualizar datos del gráfico del proyecto
        updateProjectChartData(restoredProject);

        // Liberar la memoria de tareas vinculadas
        _freeProject(project);
      }

      // Actualiza la lista de proyectos
      await loadProjects();

      ShowMessage.projectRestored(restoredProject);
    }, 'No se ha podido restaurar el proyecto');
  }

  // Libera la memoria asociada a este proyecto si ya no se va a restaurar
  void _freeProject(Project project) {
    _deletedProjectTasks[project.id]?.clear();
    _deletedProjectTasks.remove(project.id);
  }

  /// Actualiza los datos del gráfico del proyecto
  Future<void> updateProjectChartData(Project project) async {
    final isar = await _isarService.db;
    // Obtener todas las tareas del proyecto
    final List<Task> projectTasks = await isar.tasks
        .filter()
        .project((projectQuery) => projectQuery.idEqualTo(project.id))
        .findAll();

    // Agregar todos los TimeEntries de las tareas del proyecto en la última semana
    Map<DateTime, double> dailyMinutesMap = {};

    final now = DateTime.now();
    final lastWeek = now.subtract(Duration(days: 7));

    for (Task task in projectTasks) {
      await task.timeHistory.load();
      for (TimeEntry entry in task.timeHistory) {
        if (entry.day.isAfter(lastWeek)) {
          dailyMinutesMap.update(
            entry.day,
            (value) => value + entry.duration.totalMinutes,
            ifAbsent: () => entry.duration.totalMinutes,
          );
        }
      }
    }

    // Ordenar por fecha
    final sortedEntries = dailyMinutesMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    // Preparar etiquetas y datos
    final labels = sortedEntries.map((e) {
      return ChartLabel(label: '${e.key.day}/${e.key.month}', value: e.key);
    }).toList();

    final points = sortedEntries.asMap().entries.map((e) {
      return ChartPoint(dayIndex: e.key, minutes: e.value.value);
    }).toList();

    _projectChartData[project.id] = ChartData(
      points: points,
      labels: labels,
    );

    // Crear el StreamController si es necesario
    if (!_projectChartControllers.containsKey(project.id)) {
      _projectChartControllers[project.id] =
          StreamController<ChartData>.broadcast();
    }
    _projectChartControllers[project.id]!.add(_projectChartData[project.id]!);
  }

  // Obtén los datos del gráfico de un proyecto
  ChartData? getChartDataForProject(Id projectId) {
    return _projectChartData[projectId];
  }

  // Stream para los datos del gráfico del proyecto
  Stream<ChartData> getChartDataStream(Id projectId) {
    if (!_projectChartControllers.containsKey(projectId)) {
      _projectChartControllers[projectId] =
          StreamController<ChartData>.broadcast();
      // Emitir los datos actuales
      if (_projectChartData.containsKey(projectId)) {
        _projectChartControllers[projectId]!.add(_projectChartData[projectId]!);
      }
    }
    return _projectChartControllers[projectId]!.stream;
  }

  // Cerrar los streams
  @override
  void dispose() {
    _projectChartControllers
        .forEach((projectId, controller) => controller.close());
    super.dispose();
  }
}
