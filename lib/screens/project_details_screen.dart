import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chart_data.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../providers/navigation_provider.dart';
import '../providers/project_provider.dart';
import '../providers/task_provider.dart';
import '../services/timer_service.dart';
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
  final _updateProjectTimer =
      TimerService(tickDuration: const Duration(seconds: 1)); // throttle

  late final TaskProvider _taskProvider;
  late final ProjectProvider _projectProvider;

  List<Task> _projectTasks = [];

  int _totalEstimatedMillis = 0;
  int _totalMilliseconds = 0;
  int _avgMilliseconds = 0;
  double _deviation = 0;

  late bool _isVertical;
  late double _chartHeight;

  bool _allowRebuild = true;

  @override
  void initState() {
    super.initState();
    _taskProvider = context.read<TaskProvider>();
    _projectProvider = context.read<ProjectProvider>();
    _taskProvider.addListener(_updateProjectTimeAndChartThrottle);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calculateSizes();
    _updateProjectTimeAndChart();
    _listenProjectTimeUpdates();
  }

  @override
  void dispose() {
    _updateProjectTimer.stopAll();
    _taskProvider.removeListener(_updateProjectTimeAndChartThrottle);
    super.dispose();
  }

  /// Permite actualizar los datos del proyecto cada segundo si alguna tarea está en marcha
  void _listenProjectTimeUpdates() {
    _updateProjectTimer.startTimer(widget.project.id, onTick: () {
      _allowRebuild = true;
      // Comprueba que hay tareas en marcha o pausa las actualizaciones
      if (!_projectTasks.any((task) => task.isRunning)) {
        _updateProjectTimer.stopTimer(widget.project.id);
      }
    });
  }

  void _updateProjectTimeAndChartThrottle() {
    if (_allowRebuild) {
      _allowRebuild = false;
      _updateProjectTimeAndChart();
    } else {
      log(
        enabled: false,
        'Skip _updateProjectTimeAndChartThrottle ${DateTime.now()}',
      );
    }
  }

  void _updateProjectTimeAndChart() {
    setState(() {
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

      // Actualizar gráfico
      _projectProvider.updateProjectChartData(widget.project);
    });

    log(
      enabled: false,
      '${widget.project.name} _updateProjectTimeAndChart ${DateTime.now()}',
    );
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
    return Consumer<ProjectProvider>(
        builder: (context, projectProvider, child) {
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
                            backgroundColor:
                                Theme.of(context).colorScheme.error,
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
                    NavigationProvider.instance
                        ?.navigateToPage(AppPage.projects);
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
                                        .formatOptionalSeconds(),
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
                                            .formatOptionalSeconds(),
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
            SliverToBoxAdapter(
              child: StreamBuilder<ChartData>(
                initialData:
                    projectProvider.getChartDataForProject(widget.project.id),
                stream: projectProvider.getChartDataStream(widget.project.id),
                builder: (_, snapshot) {
                  final ChartData? chartData = snapshot.data;
                  bool hasChartData =
                      snapshot.hasData && chartData!.points.isNotEmpty;

                  return Padding(
                    padding:
                        const EdgeInsets.only(left: 10, right: 16, bottom: 16),
                    child: Container(
                      height: _chartHeight,
                      constraints: hasChartData
                          ? const BoxConstraints(minHeight: 200)
                          : const BoxConstraints(maxHeight: 100),
                      child: hasChartData
                          ? TimeChart(
                              chartData: chartData.points,
                              chartLabels: chartData.labels,
                            )
                          : _totalMilliseconds == 0
                              ? const Center(
                                  child: Text('Sin tiempo registrado'))
                              : const SizedBox.shrink(),
                    ),
                  );
                },
              ),
            ),
            // Lista de Tareas
            SliverList.builder(
              itemCount: _projectTasks.length,
              itemBuilder: (_, index) {
                final task = _projectTasks[index];
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
                              iconSize: 28,
                              backgroundColor: Colors.blue.shade800,
                            ),
                            onPressed: () {
                              AddTaskDialog.showCopyDialog(context, task)
                                  .then((_) {
                                // Actualizar tareas y tiempos
                                _updateProjectTimeAndChart();
                              });
                            },
                          ),
                        )
                      :
                      // Cronómetro
                      TimerButton(
                          isRunning: task.isRunning,
                          tooltip: task.timerLabel,
                          iconSize: 28,
                          onPressed: () async {
                            _allowRebuild = true;

                            await _taskProvider.toggleTaskTimer(task);

                            if (task.isRunning) {
                              _listenProjectTimeUpdates();
                            }
                          },
                        ),
                  onTap: () {
                    context
                        .read<NavigationProvider>()
                        .navigateToTaskDetails(task)
                        .then((_) {
                      // Actualizar tareas y tiempos por si ha cambiado alguna tarea
                      _listenProjectTimeUpdates();
                      _updateProjectTimeAndChart();
                    });
                  },
                );
              },
            ),
          ],
        ),
        floatingActionButton: Tooltip(
          message: 'Añadir tarea de ${widget.project.name}',
          child: FloatingActionButton(
            child: Icon(Icons.add_box),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AddTaskDialog(projectId: widget.project.id),
              ).then((_) {
                // Actualizar tareas y tiempos
                _updateProjectTimeAndChart();
              });
            },
          ),
        ),
      );
    });
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
