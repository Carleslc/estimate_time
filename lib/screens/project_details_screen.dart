import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../providers/navigation_provider.dart';
import '../providers/project_provider.dart';
import '../providers/task_provider.dart';
import '../utils/time.dart';
import '../widgets/time_chart.dart';
import '../widgets/timer_button.dart';
import 'add_task_dialog.dart';
import 'projects_screen.dart';
import 'task_details_screen.dart';

class ProjectDetailsScreen extends StatefulWidget {
  final Project project;

  ProjectDetailsScreen({required this.project});

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  List<Task> _projectTasks = [];

  List<({int dayIndex, double minutes})> _chartData = [];
  List<String> _chartLabels = [];

  int _totalEstimatedMillis = 0;
  int _totalMilliseconds = 0;
  int _avgMilliseconds = 0;
  double _deviation = 0;

  @override
  void initState() {
    super.initState();
    _updateTimeHistoryChart();
  }

  Future<void> _updateTimeHistoryChart({bool setState = true}) async {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

    // Tareas del proyecto
    _projectTasks = taskProvider.allTasks
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
      _chartLabels.add('${entry.key.day}/${entry.key.month}');
      _chartData.add((
        dayIndex: i,
        minutes: entry.value.totalMinutes,
      ));
    }

    // debugPrint(
    //     '${widget.project.name} _updateTimeHistoryChart ${DateTime.now()}');

    if (setState) this.setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _updateTimeHistoryChart(setState: false);

    final projectProvider = Provider.of<ProjectProvider>(context);
    final taskProvider = Provider.of<TaskProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Detalles del proyecto'),
        actions: [
          Tooltip(
            message: 'Eliminar',
            child: IconButton(
              icon: Icon(Icons.delete),
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
                        child: Text('Cancelar'),
                        onPressed: () => Navigator.pop(context, false),
                      ),
                      ElevatedButton(
                        child: Text('Eliminar'),
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
                  await projectProvider.deleteProject(context, widget.project);
                  NavigationProvider.navigateToPage(context, AppPage.projects);
                }
              },
            ),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nombre con color
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: () => _editColor(context, projectProvider),
                    child: CircleAvatar(
                      backgroundColor: widget.project.color,
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _editName(context, projectProvider),
                    child: Text(
                      widget.project.name,
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            // Tiempo total
            if (_totalMilliseconds > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Tiempo total: ',
                        style: TextStyle(fontSize: 16),
                      ),
                      TextSpan(
                        text:
                            Duration(milliseconds: _totalMilliseconds).format(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Tiempo medio
            if (_projectTasks.length > 1 && _avgMilliseconds > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Tiempo medio: ',
                        style: TextStyle(fontSize: 16),
                      ),
                      TextSpan(
                        text: Duration(milliseconds: _avgMilliseconds)
                            .format(withSeconds: false),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_totalEstimatedMillis > 0)
              // Desviación media
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Desviación media: ',
                        style: TextStyle(fontSize: 16),
                      ),
                      TextSpan(
                        text: '${_deviation.round()}%',
                        style: TextStyle(
                          fontSize: 16,
                          color: _deviation > 0 ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Gráfico de tiempo total por día
            if (_chartData.isNotEmpty)
              Expanded(
                child: TimeChart(
                  chartData: _chartData,
                  chartLabels: _chartLabels,
                ),
              )
            else
              _totalMilliseconds == 0
                  ? const Center(child: Text('Sin tiempo registrado'))
                  : const SizedBox.shrink(),
            SizedBox(height: 10),
            // Lista de Tareas
            Expanded(
              child: ListView.builder(
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
                              onPressed: () =>
                                  AddTaskDialog.showCopyDialog(context, task),
                            ),
                          )
                        :
                        // Cronómetro
                        TimerButton(
                            isRunning: task.isRunning,
                            iconSize: 28,
                            onPressed: () {
                              taskProvider.toggleTaskTimer(task);
                              if (!task.isRunning) {
                                _updateTimeHistoryChart();
                              }
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

  void _editName(BuildContext context, ProjectProvider projectProvider) {
    final _controller = TextEditingController(text: widget.project.name);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Editar nombre'),
        content: TextField(
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
