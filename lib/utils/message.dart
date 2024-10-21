import 'dart:async';

import 'package:flutter/material.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../providers/navigation_provider.dart';

abstract class ShowMessage {
  static void taskArchived(BuildContext context, Task task) {
    show(
      context,
      'Tarea archivada',
      actionLabel: 'Ver',
      onAction: () {
        // Navega a la pantalla de tareas archivadas (índice 2)
        NavigationProvider.navigateToIndex(context, 2);
      },
    );
  }

  static void taskUnarchived(BuildContext context, Task task) {
    show(
      context,
      'Tarea movida a las tareas activas',
      actionLabel: 'Ver',
      onAction: () {
        // Navega a la pantalla de tareas activas (índice 0)
        NavigationProvider.navigateToIndex(context, 0);
      },
    );
  }

  static void taskDeleted(
    BuildContext context,
    Task task,
    Function(Task) restoreTask,
  ) {
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
  }

  static void taskCopied(BuildContext context, Task task) {
    show(
      context,
      'Se ha copiado la tarea',
      actionLabel: 'Ver',
      onAction: () {
        // Navega a la pantalla de tareas activas (índice 0)
        NavigationProvider.navigateToIndex(context, 0);
      },
    );
  }

  static void projectDeleted(
    BuildContext context,
    Project project,
    Function(Project) restoreProject,
  ) {
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
  }

  static void show(
    BuildContext context,
    String message, {
    int seconds = 3,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (!context.mounted) return;

    hideCurrentSnackBar(context); // Cerrar cualquier SnackBar existente

    bool hasAction = actionLabel != null && onAction != null;

    final snackbar = SnackBar(
      content: Container(
        height: 30,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(message),
        ),
      ),
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
  }

  static void hideCurrentSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }
}
