import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../providers/project_provider.dart';
import '../providers/task_provider.dart';
import '../utils/time.dart';
import 'task_details_screen.dart';

class ActiveTasksScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (_, taskProvider, __) {
        final tasks = taskProvider.tasks;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Tareas'),
          ),
          // TODO: Add dividers between tasks
          body: ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (_, index) {
              final task = tasks[index];
              return Dismissible(
                key: Key(task.id.toString()),
                direction: DismissDirection.startToEnd,
                onDismissed: (_) {
                  taskProvider.archiveTask(context, task);
                },
                background: Container(
                  color: Colors.orange,
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Icon(Icons.archive, color: Colors.white),
                ),
                child: ListTile(
                  // Título
                  title: Row(
                    children: [
                      // Proyecto (etiqueta)
                      FutureBuilder<Project?>(
                        future: task.getProject(),
                        builder: (_, snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            final project = snapshot.data!;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Chip(
                                label: Text(
                                  project.name,
                                  style: TextStyle(
                                    color: project.labelColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: project.color,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 4, vertical: -4),
                                visualDensity:
                                    VisualDensity(horizontal: -3, vertical: -3),
                              ),
                            );
                          }
                          return SizedBox.shrink();
                        },
                      ),
                      // Título
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  // Tiempo
                  subtitle: Text(
                    task.todayTime.formatTime(),
                    style: TextStyle(fontSize: 20),
                  ),
                  // Play / Pause
                  trailing: IconButton.filled(
                    icon: Icon(task.isRunning ? Icons.pause : Icons.play_arrow),
                    color: Colors.white,
                    style: IconButton.styleFrom(
                      iconSize: 32,
                      backgroundColor: task.isRunning
                          ? Colors.red.shade400
                          : Colors.green.shade400,
                    ),
                    onPressed: () {
                      taskProvider.toggleTaskTimer(task);
                    },
                  ),
                  // Detalles
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TaskDetailsScreen(task: task),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          floatingActionButton: Tooltip(
            message: 'Añadir tarea',
            child: FloatingActionButton(
              child: Icon(Icons.add),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AddTaskDialog(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AddTaskDialog extends StatefulWidget {
  final Project? project;

  const AddTaskDialog({super.key, this.project});

  @override
  _AddTaskDialogState createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  Project? _selectedProject;
  Duration? _estimatedTime;

  int _estimatedHours = 0;
  int _estimatedMinutes = 0;

  @override
  void initState() {
    super.initState();
    _selectedProject = widget.project;
  }

  @override
  Widget build(BuildContext context) {
    final projectProvider = Provider.of<ProjectProvider>(context);

    return AlertDialog(
      title: Text('Nueva tarea'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Proyecto
              DropdownButtonFormField<Project>(
                decoration: InputDecoration(
                  labelText: 'Proyecto' +
                      (widget.project == null ? ' (opcional)' : ''),
                ),
                items: [
                  DropdownMenuItem(value: null, child: Text('–')),
                  ...projectProvider.projects.map(
                    (project) => DropdownMenuItem(
                      value: project,
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: project.color,
                            radius: 8,
                          ),
                          SizedBox(width: 8),
                          Text(project.name),
                        ],
                      ),
                    ),
                  ),
                ],
                onChanged: widget.project != null
                    ? null
                    : (value) {
                        setState(() {
                          _selectedProject = value;
                        });
                      },
                value: _selectedProject,
              ),
              SizedBox(height: 10),
              // Título
              TextFormField(
                decoration: InputDecoration(labelText: 'Título'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El título es obligatorio';
                  }
                  return null;
                },
                onSaved: (value) {
                  _title = value!.trim();
                },
              ),
              SizedBox(height: 10),
              // Tiempo Estimado
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(labelText: 'Horas'),
                      keyboardType: TextInputType.number,
                      initialValue: '0',
                      onSaved: (value) {
                        _estimatedHours = int.tryParse(value ?? '0') ?? 0;
                      },
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(labelText: 'Minutos'),
                      keyboardType: TextInputType.number,
                      initialValue: '0',
                      onSaved: (value) {
                        _estimatedMinutes = int.tryParse(value ?? '0') ?? 0;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          child: Text('Cancelar'),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          child: Text('Empezar'),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              if (_estimatedHours > 0 || _estimatedMinutes > 0) {
                _estimatedTime = Duration(
                  hours: _estimatedHours,
                  minutes: _estimatedMinutes,
                );
              }
              final taskProvider =
                  Provider.of<TaskProvider>(context, listen: false);
              await taskProvider.createTask(
                  _title, _selectedProject, _estimatedTime);
              Navigator.pop(context);
            }
          },
        ),
      ],
    );
  }
}
