import 'dart:async';

import 'package:flutter/material.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../providers/navigation_provider.dart';
import 'log.dart';

abstract class ShowMessage {
  static SnackBarController? taskArchived(BuildContext context, Task task) =>
      show(
        context,
        'Tarea archivada',
        actionLabel: 'Ver',
        onAction: () {
          // Navega a la pantalla de tareas archivadas
          NavigationProvider.navigateToPage(context, AppPage.archivedTasks);
        },
      );

  static SnackBarController? taskUnarchived(BuildContext context, Task task) =>
      show(
        context,
        'Tarea movida a las tareas activas',
        actionLabel: 'Ver',
        onAction: () {
          // Navega a la pantalla de tareas activas
          NavigationProvider.navigateToPage(context, AppPage.activeTasks);
        },
      );

  static SnackBarController? taskDeleted(
    BuildContext context,
    Task task,
    Function(Task) restoreTask,
  ) =>
      show(
        context,
        'Tarea eliminada',
        seconds: 5,
        actionLabel: 'Deshacer',
        onAction: () {
          // Restaurar la tarea eliminada
          restoreTask(task);
        },
      );

  static SnackBarController? taskCopied(BuildContext context, Task task) =>
      show(
        context,
        'Se ha copiado la tarea',
        actionLabel: 'Ver',
        onAction: () {
          // Navega a la pantalla de tareas activas
          NavigationProvider.navigateToPage(context, AppPage.activeTasks);
        },
      );

  static SnackBarController? projectDeleted(
    BuildContext context,
    Project project,
    Function(Project) restoreProject,
  ) =>
      show(
        context,
        'Proyecto eliminado',
        seconds: 10,
        actionLabel: 'Deshacer',
        onAction: () {
          // Restaurar el proyecto eliminado
          restoreProject(project);
        },
      );

  static SnackBarController? error(BuildContext context, String message) {
    if (!context.mounted)
      return null; // TODO: Use a global BuildContext to show snackbars for the whole app
    return show(
      context,
      message,
      backgroundColor: Theme.of(context).colorScheme.error,
      foregroundColor: Theme.of(context).colorScheme.onError,
    );
  }

  static SnackBarController? show(
    BuildContext context,
    String message, {
    int seconds = 3,
    String? actionLabel,
    VoidCallback? onAction,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    if (!context.mounted) return null;

    hideCurrentSnackBar(context); // Cerrar cualquier SnackBar existente

    bool hasAction = actionLabel != null && onAction != null;

    final snackbar = SnackBar(
      content: Container(
        height: 30,
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
        ScaffoldMessenger.of(context).showSnackBar(snackbar);

    if (hasAction) {
      // Oculta la SnackBar automáticamente
      final hideTimer =
          Timer(Duration(seconds: seconds), snackbarController.close);

      snackbarController.closed.then((SnackBarClosedReason reason) {
        hideTimer.cancel();
      });
    }

    return snackbarController;
  }

  static void hideCurrentSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }
}

typedef SnackBarController
    = ScaffoldFeatureController<SnackBar, SnackBarClosedReason>;

Future<T?> tryOrShowError<T>(
  BuildContext context,
  Future<T?> Function() callback,
  String errorMessage,
) async {
  try {
    return await callback();
  } catch (e) {
    log('${errorMessage}: $e');
    ShowMessage.error(context, errorMessage);
    return null;
  }
}
