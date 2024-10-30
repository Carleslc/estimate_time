import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chart_data.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../providers/navigation_provider.dart';
import '../providers/task_provider.dart';
import '../utils/date.dart';
import '../utils/duration.dart';
import '../utils/strings.dart';
import '../widgets/label_value.dart';
import '../widgets/project_tag.dart';
import '../widgets/time_chart.dart';
import '../widgets/timer_button.dart';

class TaskDetailsScreen extends StatefulWidget {
  final Task task;

  TaskDetailsScreen({required this.task});

  @override
  _TaskDetailsScreenState createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  late final TaskProvider _taskProvider;

  DateTime? _estimatedEndTime;
  DateTime? _lastUpdatedTask;

  late bool _isVertical;
  late double _chartHeight;

  @override
  void initState() {
    super.initState();
    _taskProvider = context.read<TaskProvider>();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calculateSizes();
    _updateEstimatedEndTime(widget.task);
    _taskProvider.setTodayTime(widget.task);
    _taskProvider.updateTaskChartData(widget.task);
  }

  @override
  void didUpdateWidget(covariant old) {
    super.didUpdateWidget(old);
    _allowRebuild();
    _updateEstimatedEndTime(widget.task);
    _taskProvider.setTodayTime(widget.task);
    _taskProvider.updateTaskChartData(widget.task);
  }

  void _updateEstimatedEndTime(Task task) {
    if (task.estimatedTime != null && task.isRunning) {
      final remainingTime = task.estimatedTime! - task.totalTime;
      final now = DateTime.now();
      final estimatedEndTime = now.add(remainingTime);
      if (estimatedEndTime.isAfter(now)) {
        setState(() {
          _estimatedEndTime = estimatedEndTime;
        });
      }
    }
  }

  void _calculateSizes() {
    // Orientación actual
    _isVertical = MediaQuery.orientationOf(context) == Orientation.portrait;
    // Calcular la altura del gráfico
    double screenHeight = MediaQuery.sizeOf(context).height;
    double percent;
    if (_isVertical) {
      // Portrait
      percent = widget.task.estimatedTimeMillis != null
          ? 0.45
          : (widget.task.description.isNotEmpty ? 0.5 : 0.6);
    } else {
      // Landscape
      percent = 0.7; // Scroll
    }
    _chartHeight = screenHeight * percent;
  }

  String get _progressOrDeviation {
    int progressEstimation = widget.task.progressEstimation.round();
    return progressEstimation <= 100
        ? '${progressEstimation}%'
        : '+${widget.task.deviation.round()}%';
  }

  void _allowRebuild() {
    _lastUpdatedTask = null;
  }

  @override
  Widget build(BuildContext context) {
    final appBarTitle = const Text('Detalles de la tarea');

    return Selector<TaskProvider, Task?>(
        selector: (context, taskProvider) =>
            taskProvider.getTask(widget.task.id),
        shouldRebuild: (_, next) => _lastUpdatedTask != next?.lastUpdated,
        builder: (context, task, child) {
          _lastUpdatedTask = task?.lastUpdated;
          if (task == null) {
            return Scaffold(
              appBar: AppBar(title: appBarTitle),
              body: Center(child: const Text('Tarea no encontrada')),
            );
          }
          return Scaffold(
            appBar: AppBar(
              title: appBarTitle,
              // TODO: Añadir Botón Copiar en los detalles de una tarea
              actions: [
                if (task.archived)
                  // Eliminar tarea
                  Tooltip(
                    message: 'Eliminar',
                    child: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () async {
                        _allowRebuild();
                        await _taskProvider.deleteTask(task);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                // Toggle Archivar / Desarchivar
                Tooltip(
                  message: task.archived ? 'Desarchivar' : 'Archivar',
                  child: IconButton(
                    icon: Icon(task.archived ? Icons.unarchive : Icons.archive),
                    onPressed: () async {
                      _allowRebuild();
                      if (task.archived) {
                        await _taskProvider.unarchiveTask(task);
                      } else {
                        await _taskProvider.archiveTask(task);
                      }
                    },
                  ),
                ),
              ],
            ),
            body: CustomScrollView(
              slivers: [
                // Detalles de la tarea
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(left: 20, right: 20, top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Título editable
                        GestureDetector(
                          onTap: () => _editTitle(context, task),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  task.title,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 10),
                        // Etiqueta del Proyecto
                        FutureBuilder<Project?>(
                          future: task.getProject(),
                          builder: (_, snapshot) {
                            final project = snapshot.data;
                            if (project == null) return const SizedBox.shrink();
                            return GestureDetector(
                              onTap: () {
                                context
                                    .read<NavigationProvider>()
                                    .navigateToProjectDetails(project);
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: ProjectTag(project: project),
                              ),
                            );
                          },
                        ),
                        // Descripción editable
                        if (task.description.isNotBlank)
                          GestureDetector(
                            onTap: () => _editDescription(context, task),
                            child: Padding(
                              padding: EdgeInsets.only(
                                bottom: task.totalTimeMillis > 0 ? 20 : 0,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      task.description,
                                      softWrap: true,
                                      style: const TextStyle(
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // Tiempo
                        if (task.totalTimeMillis > 0)
                          LabelValue(
                            label: 'Total',
                            value: task.totalTime.formatOptionalSeconds(),
                          ),
                        if (task.todayTimeMillis != null)
                          LabelValue(
                            label: 'Hoy',
                            value: task.todayTime!.format(),
                            separator: ':   ',
                          ),
                        if (task.archived)
                          Padding(
                            padding: EdgeInsets.only(
                              top: 30,
                              bottom:
                                  task.estimatedTimeMillis != null ? 32 : 22,
                            ),
                            child: Text(
                              'Esta tarea está archivada',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          )
                        else
                          // Play / Pause
                          Padding(
                            padding: EdgeInsets.only(
                              top: 20,
                              bottom:
                                  task.estimatedTimeMillis != null ? 20 : 10,
                            ),
                            child: TimerButton(
                              isRunning: task.isRunning,
                              label: task.timerLabel,
                              onPressed: () async {
                                await _taskProvider.toggleTaskTimer(task);

                                if (task.isRunning) {
                                  // Play
                                  _updateEstimatedEndTime(task);
                                }
                              },
                            ),
                          ),
                        // Estimación de hora de finalización
                        if (task.isRunning && _estimatedEndTime != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: LabelValue(
                              label: 'Finalización estimada',
                              value: _estimatedEndTime!.formatTimeFuture(),
                              separator: ': ',
                            ),
                          ),
                        // Duración estimada
                        if (task.estimatedTimeMillis != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: LabelValue(
                              label: 'Estimación',
                              value: task.estimatedTime!.format(),
                            ),
                          ),
                        // Estadísticas
                        if (task.estimatedTimeMillis != null &&
                            task.estimatedTimeMillis! > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: LabelValue(
                              label: task.progressEstimation <= 100
                                  ? 'Progreso estimado'
                                  : 'Desviación',
                              value: _progressOrDeviation,
                              valueStyle: TextStyle(
                                color: task.deviation <= 0
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Gráfico con los datos procesados
                _chartWidget(task),
              ],
            ),
          );
        });
  }

  Widget _chartWidget(Task task) {
    final chartBuilder = StreamBuilder<ChartData>(
      initialData: _taskProvider.getChartDataForTask(task.id),
      stream: _taskProvider.getChartDataStream(task.id),
      builder: (_, snapshot) {
        final ChartData? chartData = snapshot.data;
        bool hasChartData = snapshot.hasData && chartData!.points.isNotEmpty;

        return Padding(
          padding: const EdgeInsets.only(left: 10, right: 16, bottom: 10),
          child: Container(
            height: _chartHeight,
            constraints: hasChartData
                ? const BoxConstraints(minHeight: 200)
                : BoxConstraints(
                    maxHeight: _isVertical ? double.infinity : 128),
            child: hasChartData
                ? TimeChart(
                    chartData: chartData.points,
                    chartLabels: chartData.labels,
                  )
                : task.totalTimeMillis == 0
                    ? const Center(child: Text('Sin tiempo registrado'))
                    : const SizedBox.shrink(),
          ),
        );
      },
    );
    return _isVertical
        ? SliverFillRemaining(child: chartBuilder)
        : SliverToBoxAdapter(child: chartBuilder);
  }

  void _editTitle(BuildContext context, Task task) {
    final _controller = TextEditingController(text: task.title);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar título'),
        content: TextField(
          autofocus: true,
          controller: _controller,
          decoration: const InputDecoration(labelText: 'Título'),
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text('Guardar'),
            onPressed: () async {
              final newTitle = _controller.text.trim();

              if (newTitle.isNotEmpty) {
                task.title = newTitle;
                _taskProvider.updateTask(task);
                Navigator.pop(context); // Cerrar Dialog
              }
            },
          ),
        ],
      ),
    );
  }

  void _editDescription(BuildContext context, Task task) {
    final _controller = TextEditingController(text: task.description);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar descripción'),
        content: TextField(
          controller: _controller,
          decoration: const InputDecoration(labelText: 'Descripción'),
          minLines: 3,
          maxLines: 20,
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text('Guardar'),
            onPressed: () async {
              final newDescription = _controller.text.trim();

              if (newDescription.isNotEmpty) {
                task.description = newDescription;
                _taskProvider.updateTask(task);
                Navigator.pop(context); // Cerrar Dialog
              }
            },
          ),
        ],
      ),
    );
  }
}
