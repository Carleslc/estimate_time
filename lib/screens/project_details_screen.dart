import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../providers/navigation_provider.dart';
import '../providers/project_provider.dart';
import '../providers/task_provider.dart';
import '../utils/time.dart';
import 'active_tasks_screen.dart';
import 'task_details_screen.dart';

class ProjectDetailsScreen extends StatefulWidget {
  final Project project;

  ProjectDetailsScreen({required this.project});

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  List<({int dayIndex, double seconds})> _chartData = [];
  List<String> _chartLabels = [];

  @override
  void initState() {
    super.initState();
    _loadProjectTimeHistory();
  }

  Future<void> _loadProjectTimeHistory() async {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final projectTasks = taskProvider.allTasks
        .where((task) => task.project.value?.id == widget.project.id)
        .toList();

    Map<DateTime, double> dailyTimeMap = {};

    // Agrupar tiempo total de todas las tareas por día
    for (Task task in projectTasks) {
      await task.timeHistory.load();

      for (TimeEntry entry in task.timeHistory) {
        dailyTimeMap.update(
          entry.day,
          (value) => value + entry.duration.totalSeconds,
          ifAbsent: () => entry.duration.totalSeconds,
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

    for (var (int i, MapEntry<DateTime, double> entry)
        in recentEntries.indexed) {
      _chartLabels.add('${entry.key.day}/${entry.key.month}');
      _chartData.add((
        dayIndex: i,
        seconds: entry.value,
      ));
    }

    setState(() {});
  }

  double _getMaxY() {
    double max = 0;
    for (var entry in _chartData) {
      if (entry.seconds > max) {
        max = entry.seconds;
      }
    }
    return max + 10; // Añade un margen
  }

  @override
  Widget build(BuildContext context) {
    final projectProvider = Provider.of<ProjectProvider>(context);
    final taskProvider = Provider.of<TaskProvider>(context);
    final projectTasks = taskProvider.allTasks
        .where((task) => task.project.value?.id == widget.project.id)
        .toList();

    // Calcular desviación media
    int totalMilliseconds =
        projectTasks.fold(0, (sum, task) => sum + task.totalTimeMillis);
    int totalEstimatedMillis = projectTasks.fold(
        0, (sum, task) => sum + (task.estimatedTimeMillis ?? 0));
    double deviation =
        Task.calculateDeviation(totalMilliseconds, totalEstimatedMillis);

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
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nombre con color
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: widget.project.color,
                ),
                SizedBox(width: 10),
                Text(
                  widget.project.name,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 10),
            // Tiempo total
            if (totalMilliseconds > 0)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Tiempo total: ',
                      style: TextStyle(fontSize: 16),
                    ),
                    TextSpan(
                      text: Duration(milliseconds: totalMilliseconds).format(),
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 10),
            // Desviación media
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Desviación media: ',
                    style: TextStyle(fontSize: 16),
                  ),
                  TextSpan(
                    text: '${deviation.round()}%',
                    style: TextStyle(
                      fontSize: 16,
                      color: deviation > 100 ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            // Gráfico de tiempo total por día
            if (_chartData.isNotEmpty)
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _getMaxY(),
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        axisNameWidget: Text(
                          'Tiempo (s)', // Etiqueta del eje Y
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
                            // Mostrar solo múltiplos de 5
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
                          'Día', // Etiqueta del eje X
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
                      horizontalInterval: 5,
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
                            toY: entry.seconds,
                            color:
                                Theme.of(context).colorScheme.primaryFixedDim,
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              )
            else
              Center(child: Text('No hay datos para el gráfico')),
            SizedBox(height: 10),
            // Lista de Tareas
            Expanded(
              child: ListView.builder(
                itemCount: projectTasks.length,
                itemBuilder: (_, index) {
                  final task = projectTasks[index];
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
                                iconSize: 26,
                                backgroundColor: Colors.blue.shade800,
                              ),
                              onPressed: () {
                                taskProvider.copyTask(context, task);
                              },
                            ),
                          )
                        :
                        // Cronómetro
                        IconButton.filled(
                            icon: Icon(task.isRunning
                                ? Icons.pause
                                : Icons.play_arrow),
                            color: Colors.white,
                            style: IconButton.styleFrom(
                              iconSize: 26,
                              backgroundColor: task.isRunning
                                  ? Colors.red.shade400
                                  : Colors.green.shade400,
                            ),
                            onPressed: () {
                              taskProvider.toggleTaskTimer(task);
                              if (!task.isRunning) {
                                _loadProjectTimeHistory();
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
            builder: (_) => AddTaskDialog(
              project: projectProvider.projects.firstWhere(
                (project) => project.id == widget.project.id,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
