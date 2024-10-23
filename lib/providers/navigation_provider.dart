import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../screens/project_details_screen.dart';
import '../screens/task_details_screen.dart';

enum AppPage { activeTasks, projects, archivedTasks }

class NavigationProvider with ChangeNotifier {
  AppPage _currentPage = AppPage.activeTasks;

  AppPage get currentPage => _currentPage;

  void setPage(AppPage page) {
    if (_currentPage != page) {
      _currentPage = page;
      notifyListeners();
    }
  }

  static void navigateToPage(BuildContext context, AppPage page) {
    if (!context.mounted) return;
    context.read<NavigationProvider>().setPage(page);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<T?> navigateToTaskDetails<T extends Object?>(
    BuildContext context,
    Task task,
  ) async {
    // Verificar si la pantalla de la tarea ya está en la pila de rutas
    for (final route in routeObserver.routes) {
      if (route.settings.arguments is Task) {
        final routeTask = route.settings.arguments as Task;
        if (routeTask.id == task.id) {
          // La pantalla ya existe en la pila, navega a ella
          Navigator.of(context).popUntil((r) => r == route);
          return null;
        }
      }
    }

    // Si no se encuentra la pantalla, agregar una nueva
    return await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailsScreen(task: task),
        settings: RouteSettings(arguments: task),
      ),
    );
  }

  Future<T?> navigateToProjectDetails<T extends Object?>(
    BuildContext context,
    Project project,
  ) async {
    // Verificar si la pantalla del proyecto ya está en la pila de rutas
    for (final route in routeObserver.routes) {
      if (route.settings.arguments is Project) {
        final routeProject = route.settings.arguments as Project;
        if (routeProject.id == project.id) {
          // La pantalla ya existe en la pila, navega a ella
          Navigator.of(context).popUntil((r) => r == route);
          return null;
        }
      }
    }

    // Si no se encuentra la pantalla, agregar una nueva
    return await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectDetailsScreen(project: project),
        settings: RouteSettings(arguments: project),
      ),
    );
  }
}

/// Construye la lista de rutas para poder iterarla manualmente buscando ciclos cerrados
class NavigationRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  final List<PageRoute<dynamic>> _routes = [];

  List<PageRoute<dynamic>> get routes => List.unmodifiable(_routes);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute) {
      _routes.add(route);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route is PageRoute) {
      _routes.remove(route);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (route is PageRoute) {
      _routes.remove(route);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (oldRoute is PageRoute) {
      _routes.remove(oldRoute);
    }
    if (newRoute is PageRoute) {
      _routes.add(newRoute);
    }
  }
}

final NavigationRouteObserver routeObserver = NavigationRouteObserver();
