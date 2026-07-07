import 'dart:async';

import 'package:flutter/material.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../providers/navigation_provider.dart';
import 'log.dart';

abstract class ShowMessage {
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static late ColorScheme _colorScheme;

  static void initColors(ColorScheme colorScheme) {
    _colorScheme = colorScheme;
  }

  static void hideCurrentSnackBar() {
    scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
  }

  static SnackBarController? taskArchived(Task task) => show(
        'Tarea archivada',
        actionLabel: 'Ver',
        onAction: () {
          // Navega a la pantalla de tareas archivadas
          NavigationProvider.instance?.navigateToPage(AppPage.archivedTasks);
        },
      );

  static SnackBarController? taskUnarchived(Task task) => show(
        'Tarea movida a las tareas activas',
        actionLabel: 'Ver',
        onAction: () {
          // Navega a la pantalla de tareas activas
          NavigationProvider.instance?.navigateToPage(AppPage.activeTasks);
        },
      );

  static SnackBarController? taskDeleted(
    Task task,
    Function(Task) restoreTask,
  ) =>
      show(
        'Tarea eliminada',
        seconds: 6,
        actionLabel: 'Deshacer',
        onAction: () {
          // Restaurar la tarea eliminada
          restoreTask(task);
        },
      );

  static SnackBarController? taskRestored(Task task) => show(
        'Tarea restaurada: ${task.title}',
        actionLabel: 'Ver',
        onAction: () {
          // Navega a la pantalla de tareas archivadas
          NavigationProvider.instance?.navigateToPage(AppPage.archivedTasks);
        },
      );

  static SnackBarController? taskCopied(Task task) => show(
        'Se ha copiado la tarea',
        actionLabel: 'Ver',
        onAction: () {
          // Navega a la pantalla de tareas activas
          NavigationProvider.instance?.navigateToPage(AppPage.activeTasks);
        },
      );

  static SnackBarController? projectDeleted(
    Project project,
    Function(Project) restoreProject,
  ) =>
      show(
        'Proyecto eliminado',
        seconds: 10,
        actionLabel: 'Deshacer',
        onAction: () {
          // Restaurar el proyecto eliminado
          restoreProject(project);
        },
      );

  static SnackBarController? projectRestored(Project project) => show(
        'Proyecto restaurado: ${project.name}',
        actionLabel: 'Ver',
        onAction: () {
          // Navega a la pantalla de proyectos
          NavigationProvider.instance?.navigateToPage(AppPage.projects);
        },
      );

  static SnackBarController? error(String message) {
    return show(
      message,
      backgroundColor: _colorScheme.error,
      foregroundColor: _colorScheme.onError,
    );
  }

  static SnackBarController? show(
    String message, {
    int seconds = 3,
    String? actionLabel,
    VoidCallback? onAction,
    Color? backgroundColor,
    Color? foregroundColor,
    double? height = 30,
  }) {
    hideCurrentSnackBar(); // Cerrar cualquier SnackBar existente

    bool hasAction = actionLabel != null && onAction != null;

    final snackbar = SnackBar(
      content: SizedBox(
        height: height,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(message, style: TextStyle(color: foregroundColor)),
        ),
      ),
      backgroundColor: backgroundColor,
      duration: Duration(seconds: seconds),
      action: hasAction
          ? SnackBarAction(
              label: actionLabel,
              onPressed: onAction,
            )
          : null,
    );

    final snackbarController =
        scaffoldMessengerKey.currentState?.showSnackBar(snackbar);

    if (hasAction && snackbarController != null) {
      // Oculta la SnackBar automáticamente
      final hideTimer =
          Timer(Duration(seconds: seconds), snackbarController.close);

      snackbarController.closed.then((SnackBarClosedReason reason) {
        hideTimer.cancel();
      });
    }

    return snackbarController;
  }
}

typedef SnackBarController
    = ScaffoldFeatureController<SnackBar, SnackBarClosedReason>;

Future<T?> tryOrShowError<T>(
  Future<T?> Function() callback,
  String errorMessage,
) async {
  try {
    return await callback();
  } catch (e) {
    log('$errorMessage: $e');
    ShowMessage.error(errorMessage);
    return null;
  }
}
