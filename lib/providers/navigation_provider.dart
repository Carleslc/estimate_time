import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../screens/active_tasks_screen.dart';
import '../screens/archived_tasks_screen.dart';
import '../screens/project_details_screen.dart';
import '../screens/projects_screen.dart';
import '../screens/task_details_screen.dart';

abstract interface class AppRoute {
  abstract final String route;
}

enum AppPage implements AppRoute {
  activeTasks('/activeTasks'),
  projects('/projects'),
  archivedTasks('/archivedTasks');

  final String route;

  const AppPage(this.route);
}

enum AppScreen implements AppRoute {
  taskDetails('/taskDetails'),
  projectDetails('/projectDetails');

  final String route;

  const AppScreen(this.route);
}

class NavigationProvider with ChangeNotifier {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static RouteObserver get routeObserver => _routeObserver;
  static final _routeObserver = _NavigationRouteObserver();

  // App routes
  static final routes = {
    AppPage.activeTasks.route: (context) => ActiveTasksScreen(),
    AppPage.projects.route: (context) => ProjectsScreen(),
    AppPage.archivedTasks.route: (context) => ArchivedTasksScreen(),
    AppScreen.taskDetails.route: (context) {
      final Task task = ModalRoute.of(context)!.settings.arguments as Task;
      return TaskDetailsScreen(task: task);
    },
    AppScreen.projectDetails.route: (context) {
      final Project project =
          ModalRoute.of(context)!.settings.arguments as Project;
      return ProjectDetailsScreen(project: project);
    },
  };

  static NavigationProvider? get instance =>
      navigatorKey.currentContext?.read<NavigationProvider>();

  AppPage _currentPage = AppPage.activeTasks;

  AppPage get currentPage => _currentPage;

  void setPage(AppPage page) {
    if (_currentPage != page) {
      _currentPage = page;
      notifyListeners();
    }
  }

  void navigateToPage(final AppPage page) {
    // Actualiza la página actual
    setPage(page);

    // Navega a la página principal con la página actual
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  Future<T?> navigateToTaskDetails<T extends Object?>(Task task) async {
    // Verificar si la pantalla de la tarea ya está en la pila de rutas
    for (final route in _routeObserver.routes) {
      if (route.settings.arguments is Task) {
        final routeTask = route.settings.arguments as Task;
        if (routeTask.id == task.id) {
          // La pantalla ya existe en la pila, navega a ella
          navigatorKey.currentState?.popUntil((r) => r == route);
          return null;
        }
      }
    }

    // Si no se encuentra la pantalla, agregar una nueva
    return await navigatorKey.currentState?.pushNamed(
      AppScreen.taskDetails.route,
      arguments: task,
    );
  }

  Future<T?> navigateToProjectDetails<T extends Object?>(
    Project project,
  ) async {
    // Verificar si la pantalla del proyecto ya está en la pila de rutas
    for (final route in _routeObserver.routes) {
      if (route.settings.arguments is Project) {
        final routeProject = route.settings.arguments as Project;
        if (routeProject.id == project.id) {
          // La pantalla ya existe en la pila, navega a ella
          navigatorKey.currentState?.popUntil((r) => r == route);
          return null;
        }
      }
    }

    // Si no se encuentra la pantalla, agregar una nueva
    return await navigatorKey.currentState?.pushNamed(
      AppScreen.projectDetails.route,
      arguments: project,
    );
  }
}

/// Construye la lista de rutas para poder iterarla manualmente buscando ciclos cerrados
class _NavigationRouteObserver extends RouteObserver<PageRoute<dynamic>> {
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
