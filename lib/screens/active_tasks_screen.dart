import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../providers/navigation_provider.dart';
import '../providers/task_provider.dart';
import '../utils/duration.dart';
import '../widgets/project_tag.dart';
import '../widgets/timer_button.dart';
import 'add_task_dialog.dart';

class ActiveTasksScreen extends StatefulWidget {
  @override
  State<ActiveTasksScreen> createState() => _ActiveTasksScreenState();
}

class _ActiveTasksScreenState extends State<ActiveTasksScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recarga las tareas
    context.read<TaskProvider>().loadActiveTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tareas'),
      ),
      body: Consumer<TaskProvider>(builder: (_, taskProvider, __) {
        final tasks = taskProvider.tasks;

        return tasks.isEmpty
            ? Center(child: const Text('No hay tareas'))
            : ListView.separated(
                itemCount: tasks.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (_, index) {
                  final task = tasks[index];
                  return Dismissible(
                    key: Key(task.id.toString()),
                    direction: DismissDirection.startToEnd,
                    onDismissed: (_) async {
                      await taskProvider.archiveTask(task);
                    },
                    background: Container(
                      color: Colors.orange,
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.archive, color: Colors.white),
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
                                    dense: 3,
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                          // Título
                          Text(
                            task.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      // Tiempo
                      subtitle: Text(
                        task.totalTime.formatTime(),
                        style: const TextStyle(fontSize: 20),
                      ),
                      // Play / Pause
                      trailing: TimerButton(
                        isRunning: task.isRunning,
                        tooltip: task.timerLabel,
                        onPressed: () async {
                          await taskProvider.toggleTaskTimer(task);
                        },
                      ),
                      // Detalles
                      onTap: () {
                        context
                            .read<NavigationProvider>()
                            .navigateToTaskDetails(task);
                      },
                    ),
                  );
                },
              );
      }),
      floatingActionButton: Tooltip(
        message: 'Añadir tarea',
        child: FloatingActionButton(
          heroTag: 'add_task_fab',
          child: Icon(Icons.add),
          onPressed: () => showDialog(
            context: context,
            builder: (_) => AddTaskDialog(),
          ),
        ),
      ),
    );
  }
}
