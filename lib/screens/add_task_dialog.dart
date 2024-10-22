import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../providers/project_provider.dart';
import '../providers/task_provider.dart';
import '../utils/message.dart';

class AddTaskDialog extends StatefulWidget {
  final int? projectId;
  final String? initialTitle;
  final int? estimatedHours;
  final int? estimatedMinutes;

  const AddTaskDialog({
    super.key,
    this.projectId,
    this.initialTitle,
    this.estimatedHours,
    this.estimatedMinutes,
  });

  AddTaskDialog.copy(final Task task, {Key? key})
      : this(
          key: key,
          projectId: task.project.value?.id,
          initialTitle: task.title,
          estimatedHours: task.estimatedTime?.inHours,
          estimatedMinutes:
              task.estimatedTime?.inMinutes.remainder(Duration.minutesPerHour),
        );

  @override
  _AddTaskDialogState createState() => _AddTaskDialogState();

  static Future<void> showCopyDialog(
      BuildContext context, final Task task) async {
    Task? newTask = await showDialog(
      context: context,
      builder: (_) => AddTaskDialog.copy(task),
    );
    if (newTask != null) {
      ShowMessage.taskCopied(context, newTask);
    }
  }
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  late String _title;
  Project? _selectedProject;
  Duration? _estimatedTime;

  late int _estimatedHours;
  late int _estimatedMinutes;

  List<Project> _availableProjects = [];

  @override
  void initState() {
    super.initState();
    _title = widget.initialTitle ?? '';
    _estimatedHours = widget.estimatedHours ?? 0;
    _estimatedMinutes = widget.estimatedMinutes ?? 0;
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
                icon: widget.projectId == null
                    ? const Icon(Icons.arrow_drop_down)
                    : const SizedBox.shrink(),
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
                initialValue: _title,
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
                      initialValue: _estimatedHours.toString(),
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
                      initialValue: _estimatedMinutes.toString(),
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
                final newTask = await taskProvider.createTask(
                  _title,
                  _selectedProject,
                  _estimatedTime,
                );
                Navigator.pop(context, newTask);
              }, 'No se ha podido crear la tarea');
            }
          },
        ),
      ],
    );
  }
}
