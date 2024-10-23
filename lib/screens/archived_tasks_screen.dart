import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../providers/navigation_provider.dart';
import '../providers/task_provider.dart';
import '../utils/duration.dart';
import '../widgets/project_tag.dart';
import 'add_task_dialog.dart';

class ArchivedTasksScreen extends StatefulWidget {
  @override
  State<ArchivedTasksScreen> createState() => _ArchivedTasksScreenState();
}

class _ArchivedTasksScreenState extends State<ArchivedTasksScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recarga las tareas
    context.read<TaskProvider>().loadArchivedTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (_, taskProvider, __) {
        final archivedTasks = taskProvider.archivedTasks;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Tareas archivadas'),
          ),
          body: archivedTasks.isEmpty
              ? Center(child: const Text('No hay tareas archivadas'))
              : ListView.separated(
                  itemCount: archivedTasks.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, index) {
                    final Task task = archivedTasks[index];

                    return Dismissible(
                      key: Key(task.id.toString()),
                      direction: DismissDirection.horizontal,
                      onDismissed: (direction) {
                        if (direction == DismissDirection.startToEnd) {
                          // Deslizar de izquierda a derecha para eliminar
                          taskProvider.deleteTask(context, task);
                        } else if (direction == DismissDirection.endToStart) {
                          // Deslizar de derecha a izquierda para desarchivar
                          taskProvider.unarchiveTask(context, task);
                        }
                      },
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerLeft,
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        color: Colors.green,
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.unarchive, color: Colors.white),
                      ),
                      child: ListTile(
                        // Título
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Proyecto (etiqueta)
                            FutureBuilder<Project?>(
                              future: task.getProject(),
                              builder: (_, snapshot) {
                                if (snapshot.hasData && snapshot.data != null) {
                                  final project = snapshot.data!;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ProjectTag(
                                      project: project,
                                      dense: 4,
                                    ),
                                  );
                                }
                                return SizedBox.shrink();
                              },
                            ),
                            // Título
                            Text(
                              task.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        // Tiempo
                        subtitle: Text(
                          task.totalTime.formatTime(),
                          style: TextStyle(fontSize: 16),
                        ),
                        // Desarchivar / Copiar
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tooltip(
                              message: 'Desarchivar',
                              child: IconButton(
                                icon: const Icon(Icons.unarchive),
                                style: IconButton.styleFrom(
                                  iconSize: 28,
                                ),
                                onPressed: () {
                                  taskProvider.unarchiveTask(context, task);
                                },
                              ),
                            ),
                            Tooltip(
                              message: 'Copiar',
                              child: IconButton(
                                icon: const Icon(Icons.copy),
                                color: Colors.blue.shade800,
                                style: IconButton.styleFrom(
                                  iconSize: 30,
                                ),
                                onPressed: () =>
                                    AddTaskDialog.showCopyDialog(context, task),
                              ),
                            ),
                          ],
                        ),
                        // Detalles
                        onTap: () {
                          context
                              .read<NavigationProvider>()
                              .navigateToTaskDetails(context, task)
                              .then((_) {
                            // Recarga las tareas cuando la pantalla se vuelve a mostrar
                            // Desde detalles, por si se ha eliminado la tarea
                            context.read<TaskProvider>().loadArchivedTasks();
                          });
                        },
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
