import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../services/isar_service.dart';
import '../utils/message.dart';
import 'task_provider.dart';

class ProjectProvider with ChangeNotifier {
  final IsarService isarService;

  List<Project> _projects = [];

  List<Project> get projects => UnmodifiableListView(_projects);

  // Mapa para gestionar proyectos eliminados y sus tareas vinculadas
  final Map<int, List<Task>> _deletedProjectTasks = {};

  ProjectProvider(this.isarService) {
    loadProjects();
  }

  Future<void> loadProjects() async {
    final isar = await isarService.db;
    _projects = await isar.projects.where().findAll();
    for (var project in _projects) {
      project.update();
    }
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
    _projects.add(project); // UI
    await updateProject(project); // DB
  }

  Future<void> updateProject(Project project) async {
    final isar = await isarService.db;
    await isar.writeTxn(() async {
      await isar.projects.put(project);
    });
  }

  Future<void> deleteProject(BuildContext context, Project project) {
    return tryOrShowError(context, () async {
      // Elimina el proyecto (UI)
      _projects.remove(project);

      final isar = await isarService.db;

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

      notifyListeners();

      ShowMessage.projectDeleted(
        context,
        project,
        (deletedProject) async {
          await restoreProject(context, deletedProject);
        },
      )?.closed.then((SnackBarClosedReason reason) {
        if (reason != SnackBarClosedReason.action) {
          // Proyecto permanentemente eliminado
          _freeProject(project);
        }
      });
    }, 'No se ha podido eliminar el proyecto');
  }

  Future<void> restoreProject(BuildContext context, Project project) async {
    return tryOrShowError(context, () async {
      // Restaurar el proyecto
      await updateProject(project); // DB

      // Obtener la instancia restaurada del proyecto
      final isar = await isarService.db;
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
            await isar.tasks.update(task);
          }
        });

        // Tareas restauradas
        _freeProject(project);
      }

      // Reload projects list
      await loadProjects();
    }, 'No se ha podido restaurar el proyecto');
  }

  // Libera la memoria asociada a este proyecto si ya no se va a restaurar
  void _freeProject(Project project) {
    _deletedProjectTasks[project.id]?.clear();
    _deletedProjectTasks.remove(project.id);
  }
}
