import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../providers/navigation_provider.dart';
import '../providers/project_provider.dart';
import '../providers/task_provider.dart';
import '../utils/time.dart';
import 'active_tasks_screen.dart';
import 'task_details_screen.dart';

class ProjectDetailsScreen extends StatelessWidget {
  final Project project;

  ProjectDetailsScreen({required this.project});

  @override
  Widget build(BuildContext context) {
    final projectProvider = Provider.of<ProjectProvider>(context);
    final taskProvider = Provider.of<TaskProvider>(context);
    final projectTasks = taskProvider.allTasks
        .where((task) => task.project.value?.id == project.id)
        .toList();

    // Calcular desviación media
    int totalSeconds =
        projectTasks.fold(0, (sum, task) => sum + task.totalTimeSeconds);
    int totalEstimatedSeconds = projectTasks.fold(
        0, (sum, task) => sum + (task.estimatedTimeSeconds ?? 0));
    double deviation =
        Task.calculateDeviation(totalSeconds, totalEstimatedSeconds);

    return Scaffold(
      appBar: AppBar(
        title: Text('Detalles del proyecto'),
        actions: [
          Tooltip(
            message: 'Eliminar',
            child: IconButton(
              icon: Icon(Icons.delete),
              // FIXME: El proyecto no se elimina estando en otra pantalla que no sea proyectos. Es decir,
              // si desde active_tasks por ejemplo entramos en los detalles de una tarea y se hace click en su etiqueta de proyecto para ir a la pantalla del proyecto,
              // si luego desde project_details se elimina el proyecto con su acción de la AppBar, al volver a la pantalla de proyectos con navigateToPage, el proyecto sigue allí sin borrarse
              onPressed: () async {
                await projectProvider.deleteProject(context, project);
                NavigationProvider.navigateToPage(context, AppPage.projects);
              },
            ),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nombre con color
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: project.color,
                ),
                SizedBox(width: 10),
                Text(
                  project.name,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 10),
            // Tiempo total
            if (totalSeconds > 0)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Tiempo total: ',
                      style: TextStyle(fontSize: 16),
                    ),
                    TextSpan(
                      text: Duration(seconds: totalSeconds).format(),
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 10),
            // Desviación media
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Desviación media: ',
                    style: TextStyle(fontSize: 16),
                  ),
                  TextSpan(
                    text: '${deviation.round()}%',
                    style: TextStyle(
                      fontSize: 16,
                      color: deviation > 100 ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            // Lista de Tareas
            Expanded(
              child: ListView.builder(
                itemCount: projectTasks.length,
                itemBuilder: (_, index) {
                  final task = projectTasks[index];
                  return ListTile(
                    title: Text(
                      task.title,
                      style: TextStyle(
                        fontWeight:
                            task.archived ? FontWeight.normal : FontWeight.bold,
                        fontStyle:
                            task.archived ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                    subtitle: Text(task.totalTime.formatTime()),
                    trailing: task.archived
                        ? Tooltip(
                            message: 'Copiar tarea',
                            child: IconButton.filled(
                              icon: const Icon(Icons.copy),
                              color: Colors.white,
                              style: IconButton.styleFrom(
                                iconSize: 26,
                                backgroundColor: Colors.blue.shade800,
                              ),
                              onPressed: () {
                                taskProvider.copyTask(context, task);
                              },
                            ),
                          )
                        :
                        // Cronómetro
                        IconButton.filled(
                            icon: Icon(task.isRunning
                                ? Icons.pause
                                : Icons.play_arrow),
                            color: Colors.white,
                            style: IconButton.styleFrom(
                              iconSize: 26,
                              backgroundColor: task.isRunning
                                  ? Colors.red.shade400
                                  : Colors.green.shade400,
                            ),
                            onPressed: () {
                              taskProvider.toggleTaskTimer(task);
                            },
                          ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TaskDetailsScreen(task: task),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Tooltip(
        message: 'Añadir tarea de ${project.name}',
        child: FloatingActionButton(
          child: Icon(Icons.add_box),
          onPressed: () => showDialog(
            context: context,
            builder: (_) => AddTaskDialog(project: project),
          ),
        ),
      ),
    );
  }
}
