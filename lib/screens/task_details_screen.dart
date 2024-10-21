import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../providers/navigation_provider.dart';
import '../providers/task_provider.dart';
import '../utils/time.dart';
import 'project_details_screen.dart';

class TaskDetailsScreen extends StatefulWidget {
  final Task task;

  TaskDetailsScreen({required this.task});

  @override
  _TaskDetailsScreenState createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  List<Map<String, dynamic>> _chartData = [];
  List<String> _chartLabels = [];

  @override
  void initState() {
    super.initState();
    _loadTimeHistory();
  }

  Future<void> _loadTimeHistory() async {
    await widget.task.timeHistory.load();
    final entries = widget.task.timeHistory.toList();

    // Filtrar la última semana
    final now = DateTime.now();
    final lastWeek = now.subtract(Duration(days: 7));
    final recentEntries =
        entries.where((e) => e.date.isAfter(lastWeek)).toList();

    // Ordenar por fecha
    recentEntries.sort((a, b) => a.date.compareTo(b.date));

    // Preparar etiquetas y datos
    _chartLabels = [];
    _chartData = [];

    for (var i = 0; i < recentEntries.length; i++) {
      final entry = recentEntries[i];
      _chartLabels.add('${entry.date.day}/${entry.date.month}');
      _chartData.add({'day': i, 'seconds': entry.seconds.toDouble()});
    }

    setState(() {});
  }

  double _getMaxY() {
    double max = 0;
    for (var entry in _chartData) {
      if (entry['seconds'] > max) {
        max = entry['seconds'];
      }
    }
    return max + 60; // Añade un margen
  }

  @override
  Widget build(BuildContext context) {
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
                  NavigationProvider.navigateToIndex(context, 2);
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
      body: FutureBuilder<Project?>(
        future:
            widget.task.project.load().then((_) => widget.task.project.value),
        builder: (_, snapshot) {
          final project = snapshot.data;
          return Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título editable
                GestureDetector(
                  onTap: () => _editTitle(context, taskProvider),
                  child: Text(
                    widget.task.title,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(height: 10),
                // Etiqueta del Proyecto
                if (project != null)
                  GestureDetector(
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
                      child: Chip(
                        label: Text(
                          project.name,
                          style: TextStyle(color: project.labelColor),
                        ),
                        backgroundColor: project.color,
                      ),
                    ),
                  ),
                if (widget.task.archived)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      'Esta tarea está archivada',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                if (widget.task.estimatedTimeSeconds != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                        'Estimación:  ${widget.task.estimatedTime?.format()}'),
                  ),
                // Tiempo
                if (!widget.task.archived && widget.task.todayTimeSeconds > 0)
                  Text('Hoy:    ${widget.task.todayTime.format()}'),
                if (widget.task.totalTimeSeconds > 0)
                  Text('Total:  ${widget.task.totalTime.format()}'),
                SizedBox(height: 20),
                if (!widget.task.archived)
                  // Botón Play/Pause
                  ElevatedButton.icon(
                    icon: Icon(
                        widget.task.isRunning ? Icons.pause : Icons.play_arrow),
                    label: Text(widget.task.timerLabel),
                    onPressed: () {
                      taskProvider.toggleTaskTimer(widget.task);
                    },
                  ),
                SizedBox(height: 20),
                // Estadísticas
                if (widget.task.estimatedTimeSeconds != null &&
                    widget.task.estimatedTimeSeconds! > 0)
                  // Desviación
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Desviación media: ',
                          style: TextStyle(fontSize: 16),
                        ),
                        TextSpan(
                          text: '${widget.task.deviation.round()}%',
                          style: TextStyle(
                            fontSize: 16,
                            color: widget.task.deviation > 100
                                ? Colors.red
                                : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: 20),
                // Gráfico con fl_chart
                // FIXME: No se muestran los datos en el gráfico
                // FIXME: El eje vertical muestra los labels sin espacio suficiente y hace wrap
                Expanded(
                  child: _chartData.isNotEmpty
                      ? BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: _getMaxY(),
                            barTouchData: BarTouchData(enabled: false),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: true)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (double value, _) {
                                    if (value.toInt() < _chartLabels.length) {
                                      return SideTitleWidget(
                                        axisSide: AxisSide.bottom,
                                        child:
                                            Text(_chartLabels[value.toInt()]),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: _chartData.map((entry) {
                              return BarChartGroupData(
                                x: entry['day'] as int,
                                barRods: [
                                  BarChartRodData(
                                    toY: entry['seconds'] as double,
                                    color: Colors.blue,
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        )
                      : Center(child: Text('No hay datos para el gráfico')),
                ),
              ],
            ),
          );
        },
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
