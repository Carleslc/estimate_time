import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../models/time_entry.dart';
import '../providers/navigation_provider.dart';
import '../providers/project_provider.dart';
import '../providers/task_provider.dart';
import '../utils/duration.dart';
import '../utils/log.dart';
import '../widgets/color_picker_dialog.dart';
import '../widgets/label_value.dart';
import '../widgets/time_chart.dart';
import '../widgets/timer_button.dart';
import 'add_task_dialog.dart';

class ProjectDetailsScreen extends StatefulWidget {
  final Project project;

  ProjectDetailsScreen({required this.project});

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  late final TaskProvider _taskProvider;

  List<Task> _projectTasks = [];

  List<({int dayIndex, double minutes})> _chartData = [];
  List<({String label, DateTime value})> _chartLabels = [];

  int _totalEstimatedMillis = 0;
  int _totalMilliseconds = 0;
  int _avgMilliseconds = 0;
  double _deviation = 0;

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
    _updateTimeHistoryChart();
  }

  @override
  void dispose() {
    _taskProvider.removeListener(_updateTimeHistoryChart);
    super.dispose();
  }

  Future<void> _updateTimeHistoryChart({bool setState = true}) async {
    // Tareas del proyecto
    _projectTasks = _taskProvider.allTasks
        .where((task) => task.project.value?.id == widget.project.id)
        .toList();

    // Calcular tiempo total
    _totalMilliseconds =
        _projectTasks.fold(0, (sum, task) => sum + task.totalTimeMillis);
    _totalEstimatedMillis = _projectTasks.fold(
        0, (sum, task) => sum + (task.estimatedTimeMillis ?? 0));

    // Calcular tiempo medio
    if (_projectTasks.length > 0) {
      _avgMilliseconds = (_totalMilliseconds / _projectTasks.length).round();
    }

    // Calcular desviación media
    _deviation =
        Task.calculateDeviation(_totalMilliseconds, _totalEstimatedMillis);

    Map<DateTime, Duration> dailyTimeMap = {};

    // Agrupar tiempo total de todas las tareas por día
    for (Task task in _projectTasks) {
      await task.timeHistory.load();

      for (TimeEntry entry in task.timeHistory) {
        dailyTimeMap.update(
          entry.day,
          (value) => value + entry.duration,
          ifAbsent: () => entry.duration,
        );
      }
    }

    // Filtrar la última semana
    final now = DateTime.now();
    final lastWeek = now.subtract(Duration(days: 7));
    final recentEntries =
        dailyTimeMap.entries.where((e) => e.key.isAfter(lastWeek)).toList();

    // Ordenar por fecha
    recentEntries.sort((a, b) => a.key.compareTo(b.key));

    // Preparar etiquetas y datos
    _chartLabels = [];
    _chartData = [];

    for (var (int i, MapEntry<DateTime, Duration> entry)
        in recentEntries.indexed) {
      _chartLabels.add(
          (label: '${entry.key.day}/${entry.key.month}', value: entry.key));
      _chartData.add((
        dayIndex: i,
        minutes: entry.value.totalMinutes,
      ));
    }

    log(
      enabled: false,
      '${widget.project.name} _updateTimeHistoryChart ${DateTime.now()}',
    );

    if (setState) this.setState(() {});
  }

  void _calculateSizes() {
    // Orientación actual
    _isVertical = MediaQuery.orientationOf(context) == Orientation.portrait;
    // Calcular la altura del gráfico
    double screenHeight = MediaQuery.sizeOf(context).height;
    double percent;
    if (_isVertical) {
      // Portrait
      percent = 0.4;
    } else {
      // Landscape
      percent = 0.7; // Scroll
    }
    _chartHeight = screenHeight * percent;
  }

  @override
  Widget build(BuildContext context) {
    final projectProvider = Provider.of<ProjectProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles del proyecto'),
        actions: [
          Tooltip(
            message: 'Eliminar',
            child: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                // Confirmación antes de eliminar
                bool confirm = await showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text('Eliminar proyecto: ${widget.project.name}'),
                    content: Text(
                      '¿Estás seguro de que quieres eliminar ${widget.project.name}?\n\n'
                      'Todas las tareas asociadas serán desvinculadas.',
                    ),
                    actions: [
                      TextButton(
                        child: const Text('Cancelar'),
                        onPressed: () => Navigator.pop(context, false),
                      ),
                      ElevatedButton(
                        child: const Text('Eliminar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor:
                              Theme.of(context).colorScheme.onError,
                        ),
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ],
                  ),
                );

                if (confirm) {
                  final refreshTaskLinks = _taskProvider.loadTasks;
                  await projectProvider.deleteProject(
                    widget.project,
                    onRestored: refreshTaskLinks,
                  );
                  await refreshTaskLinks(); // actualiza las referencias
                  NavigationProvider.instance?.navigateToPage(AppPage.projects);
                }
              },
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Detalles del proyecto
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre y color
                  Row(
                    children: [
                      // Color
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: GestureDetector(
                          onTap: () => _editColor(context, projectProvider),
                          child: CircleAvatar(
                            backgroundColor: widget.project.color,
                          ),
                        ),
                      ),
                      // Nombre
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _editName(context, projectProvider),
                          child: Text(
                            widget.project.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Estadísticas
                  if (_totalMilliseconds > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Tiempo total
                            LabelValue(
                              label: 'Tiempo total',
                              value: ' ' +
                                  Duration(milliseconds: _totalMilliseconds)
                                      .format(),
                            ),
                            // Tiempo medio
                            if (_projectTasks.length > 1 &&
                                _avgMilliseconds > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: LabelValue(
                                  label: 'Tiempo medio',
                                  value:
                                      Duration(milliseconds: _avgMilliseconds)
                                          .format(withSeconds: true),
                                ),
                              ),
                            if (_totalEstimatedMillis > 0)
                              // Desviación media
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: LabelValue(
                                  label: 'Desviación media',
                                  value: '${_deviation.round()}%',
                                  valueStyle: TextStyle(
                                    color: _deviation > 0
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                ),
                              ),
                          ]),
                    ),
                ],
              ),
            ),
          ),
          // Gráfico de tiempo total por día
          _chartWidget(),
          // Lista de Tareas
          _tasksList(),
        ],
      ),
      floatingActionButton: Tooltip(
        message: 'Añadir tarea de ${widget.project.name}',
        child: FloatingActionButton(
          child: Icon(Icons.add_box),
          onPressed: () => showDialog(
            context: context,
            builder: (_) => AddTaskDialog(projectId: widget.project.id),
          ),
        ),
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
        : _totalMilliseconds == 0
            ? const Center(child: Text('Sin tiempo registrado'))
            : const SizedBox.shrink();

    final chartContainer = Padding(
      padding: const EdgeInsets.only(left: 10, right: 16, bottom: 16),
      child: Container(
        height: _chartHeight,
        constraints: hasChartData
            ? const BoxConstraints(minHeight: 200)
            : const BoxConstraints(maxHeight: 100),
        child: chart,
      ),
    );

    return SliverToBoxAdapter(child: chartContainer);
  }

  Widget _tasksList() {
    return SliverList.builder(
      itemCount: _projectTasks.length,
      itemBuilder: (_, index) {
        final task = _projectTasks[index];
        return ListTile(
          title: Text(
            task.title,
            style: TextStyle(
              fontWeight: task.archived ? FontWeight.normal : FontWeight.bold,
              fontStyle: task.archived ? FontStyle.italic : FontStyle.normal,
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
                      iconSize: 28,
                      backgroundColor: Colors.blue.shade800,
                    ),
                    onPressed: () =>
                        AddTaskDialog.showCopyDialog(context, task),
                  ),
                )
              :
              // Cronómetro
              TimerButton(
                  isRunning: task.isRunning,
                  tooltip: task.timerLabel,
                  iconSize: 28,
                  onPressed: () {
                    _taskProvider.toggleTaskTimer(task);

                    if (!task.isRunning) {
                      _updateTimeHistoryChart();
                    }
                  },
                ),
          onTap: () {
            context.read<NavigationProvider>().navigateToTaskDetails(task);
          },
        );
      },
    );
  }

  void _editName(BuildContext context, ProjectProvider projectProvider) {
    final _controller = TextEditingController(text: widget.project.name);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Editar nombre'),
        content: TextField(
          autofocus: true,
          controller: _controller,
          decoration: InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
            child: Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text('Guardar'),
            onPressed: () async {
              final newName = _controller.text.trim();

              if (newName.isNotEmpty) {
                widget.project.name = newName;
                await projectProvider.updateProject(widget.project);
                Navigator.pop(context); // Cerrar Dialog
              }
            },
          ),
        ],
      ),
    );
  }

  void _editColor(BuildContext context, ProjectProvider projectProvider) async {
    Color? color = await showDialog(
      context: context,
      builder: (_) => ColorPickerDialog(initialColor: widget.project.color),
    );

    if (color != null) {
      widget.project.color = color;
      await projectProvider.updateProject(widget.project);
    }
  }
}
