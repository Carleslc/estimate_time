import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../providers/project_provider.dart';
import '../providers/task_provider.dart';
import '../utils/message.dart';
import '../utils/time.dart';
import '../widgets/project_tag.dart';
import '../widgets/timer_button.dart';
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
          body: tasks.isEmpty
              ? Center(child: const Text('No hay tareas'))
              : ListView.separated(
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const Divider(),
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
                          style: TextStyle(fontSize: 20),
                        ),
                        // Play / Pause
                        trailing: TimerButton(
                          isRunning: task.isRunning,
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
  final int? projectId;

  const AddTaskDialog({super.key, this.projectId});

  @override
  _AddTaskDialogState createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  String _title = '';
  Project? _selectedProject;
  Duration? _estimatedTime;

  int _estimatedHours = 0;
  int _estimatedMinutes = 0;

  List<Project> _availableProjects = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableProjects();
  }

  void _loadAvailableProjects() async {
    final projectProvider = context.read<ProjectProvider>();
    await projectProvider.loadProjects();
    setState(() {
      _availableProjects = projectProvider.projects;

      if (widget.projectId != null) {
        _selectedProject = _availableProjects.firstWhere(
          (project) => project.id == widget.projectId,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
                      (widget.projectId == null ? ' (opcional)' : ''),
                ),
                items: [
                  DropdownMenuItem(value: null, child: Text('–')),
                  ..._availableProjects.map(
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
                onChanged: widget.projectId != null
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
                controller: _titleController,
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
            if (_titleController.text.isEmpty) {
              _titleController.text = 'Nueva tarea'; // default title
            }
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              if (_estimatedHours > 0 || _estimatedMinutes > 0) {
                _estimatedTime = Duration(
                  hours: _estimatedHours,
                  minutes: _estimatedMinutes,
                );
              }
              final taskProvider = context.read<TaskProvider>();

              await tryOrShowError(context, () async {
                await taskProvider.createTask(
                  _title,
                  _selectedProject,
                  _estimatedTime,
                );
                Navigator.pop(context);
              }, 'No se ha podido crear la tarea');
            }
          },
        ),
      ],
    );
  }
}
