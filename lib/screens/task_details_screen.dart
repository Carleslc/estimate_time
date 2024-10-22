import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../providers/navigation_provider.dart';
import '../providers/task_provider.dart';
import '../utils/time.dart';
import '../widgets/project_tag.dart';
import '../widgets/timer_button.dart';
import 'project_details_screen.dart';

class TaskDetailsScreen extends StatefulWidget {
  final Task task;

  TaskDetailsScreen({required this.task});

  @override
  _TaskDetailsScreenState createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  List<TimeEntry> _entries = [];

  List<({int dayIndex, double minutes})> _chartData = [];
  List<String> _chartLabels = [];

  @override
  void initState() {
    super.initState();
    _updateTimeHistoryChart();
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
      _chartLabels.add('${entry.date.day}/${entry.date.month}');
      _chartData.add((
        dayIndex: i,
        minutes: entry.duration.totalMinutes,
      ));
    }

    // debugPrint(
    //     '${widget.task.title} _updateTimeHistoryChart ${DateTime.now()}');

    if (setState) this.setState(() {});
  }

  double get _maxY {
    double max = _chartData.fold(
      0, // default
      (max, entry) => entry.minutes > max ? entry.minutes : max,
    );
    return max + 2; // Añade un margen (15 mins)
  }

  String get _progressOrDeviation {
    int progressEstimation = widget.task.progressEstimation.round();
    return progressEstimation <= 100
        ? '${progressEstimation.round()}%'
        : '+${widget.task.deviation.round()}%';
  }

  @override
  Widget build(BuildContext context) {
    _updateTimeHistoryChart(setState: false);

    final taskProvider = Provider.of<TaskProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Detalles de la tarea'),
        actions: [
          if (widget.task.archived)
            Tooltip(
              message: 'Eliminar',
              child: IconButton(
                icon: Icon(Icons.delete),
                onPressed: () async {
                  await taskProvider.deleteTask(context, widget.task);
                  NavigationProvider.navigateToPage(
                      context, AppPage.archivedTasks);
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
                  taskProvider.unarchiveTask(context, widget.task);
                } else {
                  taskProvider.archiveTask(context, widget.task);
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
            // Título editable
            GestureDetector(
              onTap: () => _editTitle(context, taskProvider),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.task.title,
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProjectDetailsScreen(project: project),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ProjectTag(project: project),
                    ),
                  );
                }),
            if (widget.task.estimatedTimeMillis != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child:
                    Text('Estimación:  ${widget.task.estimatedTime?.format()}'),
              ),
            if (widget.task.archived)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Esta tarea está archivada',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            // Tiempo
            if (!widget.task.archived && widget.task.todayTimeMillis != null)
              Text('Hoy:    ${widget.task.todayTime!.format()}'),
            if (widget.task.totalTimeMillis > 0)
              Text('Total:  ${widget.task.totalTime.format()}'),
            SizedBox(height: 10),
            if (!widget.task.archived)
              // Play / Pause
              TimerButton(
                isRunning: widget.task.isRunning,
                label: widget.task.timerLabel,
                onPressed: () {
                  taskProvider.toggleTaskTimer(widget.task);
                  if (!widget.task.isRunning) {
                    _updateTimeHistoryChart();
                  }
                },
              ),
            SizedBox(height: 20),
            // Estadísticas
            if (widget.task.estimatedTimeMillis != null &&
                widget.task.estimatedTimeMillis! > 0)
              // Desviación
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text:
                            "${widget.task.progressEstimation <= 100 ? 'Progreso estimado' : 'Desviación'}: ",
                        style: TextStyle(fontSize: 16),
                      ),
                      TextSpan(
                        text: _progressOrDeviation,
                        style: TextStyle(
                          fontSize: 16,
                          color: widget.task.deviation <= 0
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Gráfico de tiempo por día
            Expanded(
              child: _chartData.isNotEmpty
                  ? BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: _maxY,
                        barTouchData: BarTouchData(enabled: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            axisNameWidget: Text(
                              'Tiempo (mins)', // Y
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            axisNameSize: 30,
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: 5,
                              getTitlesWidget: (value, _) {
                                // múltiplos de 5 mins
                                if (value % 5 == 0) {
                                  return SideTitleWidget(
                                    axisSide: AxisSide.left,
                                    child: Text(
                                      value.toInt().toString(),
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            axisNameWidget: Text(
                              'Día', // X
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            axisNameSize: 30,
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (double value, _) {
                                if (value.toInt() < _chartLabels.length) {
                                  return SideTitleWidget(
                                    axisSide: AxisSide.bottom,
                                    child: Text(
                                      _chartLabels[value.toInt()],
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          drawHorizontalLine: true,
                          horizontalInterval: 5, // mins
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey,
                              strokeWidth: 0.6,
                              dashArray: [5, 5],
                            );
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: _chartData.map((entry) {
                          return BarChartGroupData(
                            x: entry.dayIndex,
                            barRods: [
                              BarChartRodData(
                                toY: entry.minutes,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryFixedDim,
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    )
                  : widget.task.totalTimeMillis == 0
                      ? const Center(child: Text('Sin tiempo registrado'))
                      : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  void _editTitle(BuildContext context, TaskProvider taskProvider) {
    final _controller = TextEditingController(text: widget.task.title);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Editar título'),
        content: TextField(
          controller: _controller,
          decoration: InputDecoration(labelText: 'Título'),
        ),
        actions: [
          TextButton(
            child: Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text('Guardar'),
            onPressed: () async {
              final newTitle = _controller.text.trim();
              if (newTitle.isNotEmpty) {
                widget.task.title = newTitle;
                taskProvider.updateTask(widget.task);
                Navigator.pop(context); // Cerrar Dialog
              }
            },
          ),
        ],
      ),
    );
  }
}
