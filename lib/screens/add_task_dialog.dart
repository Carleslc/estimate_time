import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../providers/project_provider.dart';
import '../providers/task_provider.dart';
import '../utils/message.dart';
import '../utils/strings.dart';
import '../widgets/required_field_label.dart';
import '../widgets/time_picker.dart';

class AddTaskDialog extends StatefulWidget {
  final int? projectId;
  final String? title;
  final String? description;
  final int? estimatedHours;
  final int? estimatedMinutes;

  const AddTaskDialog({
    super.key,
    this.projectId,
    this.title,
    this.description,
    this.estimatedHours,
    this.estimatedMinutes,
  });

  AddTaskDialog.copy(final Task task, {Key? key})
      : this(
          key: key,
          projectId: task.project.value?.id,
          title: task.title,
          description: task.description,
          estimatedHours: task.estimatedTime?.inHours,
          estimatedMinutes:
              task.estimatedTime?.inMinutes.remainder(Duration.minutesPerHour),
        );

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();

  static Future<void> showCopyDialog(
      BuildContext context, final Task task) async {
    Task? newTask = await showDialog(
      context: context,
      builder: (_) => AddTaskDialog.copy(task),
    );
    if (newTask != null) {
      ShowMessage.taskCopied(newTask);
    }
  }
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _estimatedHoursController = TextEditingController();
  final _estimatedMinutesController = TextEditingController();

  late String _title;
  late String _description;
  Project? _selectedProject;
  Duration? _estimatedTime;

  int? _estimatedHours;
  int? _estimatedMinutes;

  List<Project> _availableProjects = [];

  late bool _requiredTitle;

  late double _dialogWidth;

  @override
  void initState() {
    super.initState();
    _title = widget.title ?? '';
    _titleController.text = _title;
    _description = widget.description ?? '';
    _descriptionController.text = _description;
    _estimatedHours = widget.estimatedHours;
    _estimatedHoursController.text = _estimatedHours?.toString() ?? '';
    _estimatedMinutes = widget.estimatedMinutes;
    _estimatedMinutesController.text = _estimatedMinutes?.toString() ?? '';
    _loadAvailableProjects();
    _requiredTitleUpdate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() {
      // Expand horizontally, max 300dp
      _dialogWidth = min(300, MediaQuery.sizeOf(context).width);
    });
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

  void _showTimePickerEstimatedTime() {
    showTimePickerDialog(
      context,
      material: _showTimePickerMaterial,
      ios: _showTimePickerCupertino,
    );
  }

  Future<void> _showTimePickerMaterial() async {
    final pickedTime = await showTimePickerMaterial(
      context: context,
      helpText: 'Tiempo estimado',
      initialEntryMode: TimePickerEntryMode.dial,
      initialTime: TimeOfDay(
        hour: _estimatedHoursController.text.parseIntOrZero(),
        minute: _estimatedMinutesController.text.parseIntOrZero(),
      ),
    );

    if (pickedTime != null) {
      setState(() {
        _estimatedHours = pickedTime.hour;
        _estimatedHoursController.text = _estimatedHours.toString();
        _estimatedMinutes = pickedTime.minute;
        _estimatedMinutesController.text = _estimatedMinutes.toString();
      });
    }
  }

  void _showTimePickerCupertino() {
    showTimePickerCupertino(
        context: context,
        mode: CupertinoTimerPickerMode.hm,
        initialTimerDuration: Duration(
          hours: _estimatedHoursController.text.parseIntOrZero(),
          minutes: _estimatedMinutesController.text.parseIntOrZero(),
        ),
        onTimerDurationChanged: (Duration pickDuration) {
          setState(() {
            _estimatedHours = pickDuration.inHours;
            _estimatedHoursController.text = _estimatedHours.toString();
            _estimatedMinutes = pickDuration.inMinutes;
            _estimatedMinutesController.text = _estimatedMinutes.toString();
          });
        });
  }

  void _requiredTitleUpdate() {
    _requiredTitle =
        _titleController.text.isNotEmpty && _titleController.text.isBlank;
  }

  bool get isCopy => widget.title != null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        isCopy ? 'Copiar: ${widget.title}' : 'Nueva tarea',
        overflow: TextOverflow.ellipsis,
      ),
      insetPadding: const EdgeInsets.symmetric(
        // Outside padding
        horizontal: 48,
        vertical: 20,
      ),
      content: SizedBox(
        width: _dialogWidth,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Proyecto
                DropdownButtonFormField<Project>(
                  decoration: const InputDecoration(labelText: 'Proyecto'),
                  icon: widget.projectId == null
                      ? const Icon(Icons.arrow_drop_down)
                      : const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('–')),
                    ..._availableProjects.map(
                      (project) => DropdownMenuItem(
                        value: project,
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: project.color,
                              radius: 8,
                            ),
                            const SizedBox(width: 8),
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
                  initialValue: _selectedProject,
                ),
                const SizedBox(height: 10),
                // Título
                TextFormField(
                  autofocus: widget.title == null,
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: _requiredTitle ? null : 'Título',
                    label: _requiredTitle
                        ? RequiredFieldLabel(
                            labelText: 'Título',
                          )
                        : null,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      setState(() {
                        _requiredTitleUpdate();
                      });
                      return 'El título es obligatorio';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _title = value!.trim();
                  },
                  onTapOutside: (_) {
                    FocusScope.of(context).unfocus();
                  },
                ),
                const SizedBox(height: 10),
                // Descripción
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  minLines: 2,
                  maxLines: 10,
                  // TODO: Avoid requesting focus on time picker close (same in title)
                  canRequestFocus: true,
                  onSaved: (value) {
                    _description = value?.trim() ?? '';
                  },
                  onTapOutside: (_) {
                    FocusScope.of(context).unfocus();
                  },
                ),
                const SizedBox(height: 10),
                // Tiempo Estimado
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _estimatedHoursController,
                        decoration: const InputDecoration(labelText: 'Horas'),
                        keyboardType: TextInputType.number,
                        onSaved: (value) {
                          _estimatedHours = value.parseIntOrZero();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _estimatedMinutesController,
                        decoration: const InputDecoration(labelText: 'Minutos'),
                        keyboardType: TextInputType.number,
                        onSaved: (value) {
                          _estimatedMinutes = value.parseIntOrZero();
                        },
                      ),
                    ),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.access_time),
                      onPressed: _showTimePickerEstimatedTime,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Cancelar'),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text('Añadir'),
          ),
          onPressed: () async {
            if (_titleController.text.isEmpty) {
              _titleController.text = 'Nueva tarea'; // default title
            }
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              _estimatedHours ??= 0;
              _estimatedMinutes ??= 0;
              if (_estimatedHours! > 0 || _estimatedMinutes! > 0) {
                _estimatedTime = Duration(
                  hours: _estimatedHours!,
                  minutes: _estimatedMinutes!,
                );
              }
              final taskProvider = context.read<TaskProvider>();

              await tryOrShowError(() async {
                final newTask = await taskProvider.createTask(
                  _title,
                  _description,
                  _selectedProject,
                  _estimatedTime,
                );
                if (context.mounted) Navigator.pop(context, newTask);
              }, 'No se ha podido crear la tarea');
            }
          },
        ),
      ],
    );
  }
}
