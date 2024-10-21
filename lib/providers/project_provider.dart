import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../services/isar_service.dart';
import '../utils/message.dart';

class ProjectProvider with ChangeNotifier {
  final IsarService isarService;

  List<Project> _projects = [];

  List<Project> get projects => UnmodifiableListView(_projects);

  // Mapa para gestionar proyectos eliminados y sus tareas vinculadas
  final Map<int, List<int>> _deletedProjectTasks = {};

  ProjectProvider(this.isarService) {
    loadProjects();
  }

  Future<void> loadProjects() async {
    final isar = await isarService.db;
    _projects = await isar.projects.where().findAll();
    notifyListeners();
  }

  Future<Project> createProject(String name, Color color) async {
    final project = Project()
      ..name = name
      ..color = color;

    await _addProject(project);

    notifyListeners();

    return project;
  }

  Future<void> _addProject(Project project) async {
    // Evitar duplicados
    if (!_projects.any((p) => p.id == project.id)) {
      _projects.add(project); // UI
    }
    await updateProject(project); // DB
  }

  Future<void> updateProject(Project project) async {
    final isar = await isarService.db;
    await isar.writeTxn(() async {
      await isar.projects.put(project);
    });
  }

  Future<void> deleteProject(BuildContext context, Project project) async {
    final isar = await isarService.db;

    // Encontrar tareas vinculadas al proyecto
    final linkedTasks = await isar.tasks
        .filter()
        .project((q) => q.idEqualTo(project.id))
        .findAll();

    // Guardar los ids de las tareas vinculadas
    _deletedProjectTasks[project.id] =
        linkedTasks.map((task) => task.id).toList();

    await isar.writeTxn(() async {
      // Desvincular tareas del proyecto
      for (var task in linkedTasks) {
        task.project.value = null;
        await isar.tasks.put(task);
      }
      // Eliminar el proyecto (DB)
      await isar.projects.delete(project.id);
    });

    // Eliminar el proyecto (UI)
    _projects.remove(project);

    notifyListeners();

    ShowMessage.projectDeleted(context, project, restoreProject)
        .closed
        .then((SnackBarClosedReason reason) {
      if (reason != SnackBarClosedReason.action) {
        // Proyecto permanentemente eliminado
        _freeProject(project);
      }
    });
  }

  // FIXME: Las tareas se desvinculan del proyecto al eliminarlo y restaurarlo, así que cuando se elimina y restaura el proyecto
  // no se muestran sus tareas en la pantalla de project_details, y no se muestra la etiqueta
  // del proyecto en las tareas de la pantalla de active_tasks o archive_tasks, ni dentro de task_details
  Future<void> restoreProject(Project project) async {
    // Restaurar el proyecto
    await _addProject(project);

    // Volver a vincular las tareas que estaban vinculadas antes de eliminar el proyecto
    final taskIds = _deletedProjectTasks[project.id];

    if (taskIds != null && taskIds.isNotEmpty) {
      final isar = await isarService.db;
      final tasksToRestore = await isar.tasks.getAll(taskIds);

      await isar.writeTxn(() async {
        for (Task? task in tasksToRestore) {
          if (task == null) continue;
          task.project.value = project;
          await isar.tasks.put(task);
        }
      });

      // Tareas restauradas
      _freeProject(project);
    }

    notifyListeners();
  }

  // Libera la memoria asociada a este proyecto si ya no se va a restaurar
  void _freeProject(Project project) {
    _deletedProjectTasks[project.id]?.clear();
    _deletedProjectTasks.remove(project.id);
  }
}
