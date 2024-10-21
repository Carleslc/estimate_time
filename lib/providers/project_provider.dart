import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

import '../models/project.dart';
import '../services/isar_service.dart';
import '../utils/message.dart';

class ProjectProvider with ChangeNotifier {
  final IsarService isarService;

  List<Project> _projects = [];

  List<Project> get projects => UnmodifiableListView(_projects);

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

    await addProject(project);

    return project;
  }

  Future<void> addProject(Project project) async {
    _projects.add(project);

    await updateProject(project);
  }

  Future<void> updateProject(Project project, {bool notify = true}) async {
    final isar = await isarService.db;
    await isar.writeTxn(() async {
      await isar.projects.put(project);
    });
    if (notify) notifyListeners();
  }

  Future<void> deleteProject(BuildContext context, Project project) async {
    // Elimina el proyecto (UI)
    _projects.remove(project);

    notifyListeners();

    // Elimina el proyecto (DB)
    final isar = await isarService.db;
    await isar.writeTxn(() async {
      await isar.projects.delete(project.id);
    });

    ShowMessage.projectDeleted(context, project, restoreProject);
  }

  // FIXME: Se duplica el proyecto si se elimina estando en otra pantalla que no sea proyectos. Es decir,
  // si desde active_tasks por ejemplo entramos en los detalles de una tarea y se hace click en su etiqueta de proyecto para ir a la pantalla del proyecto,
  // si luego desde project_details se elimina el proyecto con su acción de la AppBar, al volver a la pantalla de proyectos con navigateToIndex, el proyecto sigue allí sin borrarse,
  // así que después de darle a "Deshacer", el proyecto se duplica
  // FIXME: Las tareas se desvinculan del proyecto al eliminarlo y restaurarlo, así que cuando se elimina y restaura el proyecto
  // no se muestran sus tareas en la pantalla de project_details, y no se muestra la etiqueta
  // del proyecto en las tareas de la pantalla de active_tasks o archive_tasks, ni dentro de task_details
  Future<void> restoreProject(Project project) async {
    // Restaura el proyecto
    await addProject(project);
  }
}
