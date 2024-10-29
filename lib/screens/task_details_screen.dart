import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../models/time_entry.dart';
import '../providers/navigation_provider.dart';
import '../providers/task_provider.dart';
import '../utils/date.dart';
import '../utils/duration.dart';
import '../utils/log.dart';
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

  List<TimeEntry> _entries = [];

  List<({int dayIndex, double minutes})> _chartData = [];
  List<({String label, DateTime value})> _chartLabels = [];

  DateTime? _estimatedEndTime;

  late bool _isVertical;
  late double _chartHeight;

  @override
  void initState() {
    super.initState();
    _taskProvider = context.read<TaskProvider>();
    _taskProvider.addListener(_updateTimeHistoryChart);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calculateSizes();
    _updateEstimatedEndTime();
    _updateTimeHistoryChart();
    _taskProvider.setTodayTime(widget.task);
  }

  @override
  void dispose() {
    _taskProvider.removeListener(_updateTimeHistoryChart);
    super.dispose();
  }

  Future<void> _updateTimeHistoryChart({bool setState = true}) async {
    await widget.task.timeHistory.load();

    _entries = widget.task.timeHistory.toList();

    // Filtrar la última semana
    final now = DateTime.now();
    final lastWeek = now.subtract(Duration(days: 7));
    final recentEntries =
        _entries.where((e) => e.day.isAfter(lastWeek)).toList();

    // Ordenar por fecha
    recentEntries.sort((a, b) => a.date.compareTo(b.date));

    // Preparar etiquetas y datos
    _chartLabels = [];
    _chartData = [];

    for (var (int i, TimeEntry entry) in recentEntries.indexed) {
      _chartLabels.add((
        label: '${entry.date.day}/${entry.date.month}',
        value: entry.day,
      ));
      _chartData.add((
        dayIndex: i,
        minutes: entry.duration.totalMinutes,
      ));
    }

    log(
      enabled: false,
      '${widget.task.title} _updateTimeHistoryChart ${DateTime.now()}',
    );

    if (setState) this.setState(() {});
  }

  void _updateEstimatedEndTime() {
    if (widget.task.estimatedTime != null && widget.task.isRunning) {
      final remainingTime = widget.task.estimatedTime! - widget.task.totalTime;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalles de la tarea'),
        // TODO: Añadir Botón Copiar en los detalles de una tarea
        actions: [
          if (widget.task.archived)
            // Eliminar tarea
            Tooltip(
              message: 'Eliminar',
              child: IconButton(
                icon: Icon(Icons.delete),
                onPressed: () async {
                  await _taskProvider.deleteTask(context, widget.task);
                  NavigationProvider.navigateToPage(
                    context,
                    AppPage.archivedTasks,
                  );
                },
              ),
            ),
          // Toggle Archivar / Desarchivar
          Tooltip(
            message: widget.task.archived ? 'Desarchivar' : 'Archivar',
            child: IconButton(
              icon:
                  Icon(widget.task.archived ? Icons.unarchive : Icons.archive),
              onPressed: () {
                if (widget.task.archived) {
                  _taskProvider.unarchiveTask(context, widget.task);
                } else {
                  _taskProvider.archiveTask(context, widget.task);
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
              padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Título editable
                  GestureDetector(
                    onTap: () => _editTitle(context),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.task.title,
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
                    future: widget.task.getProject(),
                    builder: (_, snapshot) {
                      final project = snapshot.data;
                      if (project == null) return const SizedBox.shrink();
                      return GestureDetector(
                        onTap: () {
                          context
                              .read<NavigationProvider>()
                              .navigateToProjectDetails(context, project);
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ProjectTag(project: project),
                        ),
                      );
                    },
                  ),
                  // Descripción editable
                  if (widget.task.description.isNotBlank)
                    GestureDetector(
                      onTap: () => _editDescription(context),
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: widget.task.totalTimeMillis > 0 ? 20 : 0,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.task.description,
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
                  if (widget.task.totalTimeMillis > 0)
                    LabelValue(
                      label: 'Total',
                      value: widget.task.totalTime.format(),
                    ),
                  if (widget.task.todayTimeMillis != null)
                    LabelValue(
                      label: 'Hoy',
                      value: widget.task.todayTime!.format(),
                      separator: ':   ',
                    ),
                  if (widget.task.archived)
                    Padding(
                      padding: EdgeInsets.only(
                        top: 30,
                        bottom:
                            widget.task.estimatedTimeMillis != null ? 32 : 22,
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
                            widget.task.estimatedTimeMillis != null ? 20 : 10,
                      ),
                      child: TimerButton(
                        isRunning: widget.task.isRunning,
                        label: widget.task.timerLabel,
                        onPressed: () async {
                          await _taskProvider.toggleTaskTimer(widget.task);

                          if (widget.task.isRunning) {
                            // Play
                            _updateEstimatedEndTime();
                          } else {
                            // Pause
                            _updateTimeHistoryChart();
                          }
                        },
                      ),
                    ),
                  // Estimación de hora de finalización
                  if (widget.task.isRunning && _estimatedEndTime != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: LabelValue(
                        label: 'Finalización estimada',
                        value: _estimatedEndTime!.formatTimeFuture(),
                        separator: ': ',
                      ),
                    ),
                  // Duración estimada
                  if (widget.task.estimatedTimeMillis != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: LabelValue(
                        label: 'Estimación',
                        value: widget.task.estimatedTime!.format(),
                      ),
                    ),
                  // Estadísticas
                  if (widget.task.estimatedTimeMillis != null &&
                      widget.task.estimatedTimeMillis! > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: LabelValue(
                        label: widget.task.progressEstimation <= 100
                            ? 'Progreso estimado'
                            : 'Desviación',
                        value: _progressOrDeviation,
                        valueStyle: TextStyle(
                          color: widget.task.deviation <= 0
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          _chartWidget(),
        ],
      ),
    );
  }

  Widget _chartWidget() {
    bool hasChartData = _chartData.isNotEmpty;

    final chart = hasChartData
        ? TimeChart(
            chartData: _chartData,
            chartLabels: _chartLabels,
          )
        : widget.task.totalTimeMillis == 0
            ? const Center(child: Text('Sin tiempo registrado'))
            : const SizedBox.shrink();

    final chartContainer = Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 16, 10),
      child: Container(
        height: _chartHeight,
        constraints: hasChartData
            ? const BoxConstraints(minHeight: 200)
            : BoxConstraints(maxHeight: _isVertical ? double.infinity : 128),
        child: chart,
      ),
    );

    if (hasChartData && _isVertical) {
      return SliverFillRemaining(child: chartContainer);
    }
    return SliverToBoxAdapter(child: chartContainer);
  }

  void _editTitle(BuildContext context) {
    final _controller = TextEditingController(text: widget.task.title);

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
                widget.task.title = newTitle;
                _taskProvider.updateTask(widget.task);
                Navigator.pop(context); // Cerrar Dialog
              }
            },
          ),
        ],
      ),
    );
  }

  void _editDescription(BuildContext context) {
    final _controller = TextEditingController(text: widget.task.description);

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
                widget.task.description = newDescription;
                _taskProvider.updateTask(widget.task);
                Navigator.pop(context); // Cerrar Dialog
              }
            },
          ),
        ],
      ),
    );
  }
}
