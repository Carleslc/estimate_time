import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/chart_data.dart';
import '../utils/date.dart';
import '../utils/duration.dart';

class TimeChart extends StatelessWidget {
  final List<ChartPoint> chartData;
  final List<ChartLabel> chartLabels;

  final String axisX;
  late final double _maxY;

  TimeChart({
    Key? key,
    required this.chartData,
    required this.chartLabels,
    this.axisX = 'Día',
  }) : super(key: key) {
    _maxY = chartData.fold(
      0, // default
      (max, entry) => entry.minutes > max ? entry.minutes : max,
    );
  }

  double _intervalY(double maxY) {
    if (maxY <= 5) {
      return 1; // min
    } else if (maxY <= 15) {
      return 5; // mins
    } else if (maxY <= 30) {
      return 10; // mins
    } else if (maxY <= hourInMinutes) {
      return 15; // mins
    } else if (maxY <= 8 * hourInMinutes) {
      return hourInMinutes; // 1 h
    } else if (maxY <= 48 * hourInMinutes) {
      return 10 * hourInMinutes; // 10 h
    } else {
      return 24 * hourInMinutes; // 24 h
    }
  }

  bool _axisYinMinutes(double maxY) => maxY <= hourInMinutes; // < 1h

  @override
  Widget build(BuildContext context) {
    final intervalY = _intervalY(_maxY);
    final axisYinMinutes = _axisYinMinutes(_maxY);

    final colorScheme = Theme.of(context).colorScheme;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _maxY + intervalY, // maxY + margin
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => colorScheme.surfaceContainer,
            tooltipPadding: const EdgeInsets.all(8),
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String dayLabel =
                  chartLabels[group.x.toInt()].value.formatDateMEd();

              double minutes = rod.toY;
              double milliseconds = minutes * Duration.millisecondsPerMinute;
              Duration duration = Duration(milliseconds: milliseconds.toInt());
              String formattedValue = duration.format(withSeconds: true);

              return BarTooltipItem(
                '$dayLabel\n', // Fecha
                TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                children: [
                  TextSpan(
                    text: formattedValue, // Tiempo
                    style: TextStyle(
                      color: colorScheme.onSecondaryContainer,
                      fontSize: 14,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            axisNameWidget: Text(
              'Tiempo (${axisYinMinutes ? 'mins' : 'hrs'})', // Y
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            axisNameSize: 30,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: intervalY,
              getTitlesWidget: (minutes, _) {
                if (minutes % intervalY == 0) {
                  return SideTitleWidget(
                    axisSide: AxisSide.left,
                    child: Text(
                      axisYinMinutes
                          ? minutes.toInt().toString()
                          : (minutes / hourInMinutes).toStringAsFixed(0),
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: Text(
              axisX, // X
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            axisNameSize: 30,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (double value, _) {
                if (value.toInt() < chartLabels.length) {
                  return SideTitleWidget(
                    axisSide: AxisSide.bottom,
                    child: Text(
                      chartLabels[value.toInt()].label,
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
          horizontalInterval: intervalY / 2,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey,
              strokeWidth: 0.6,
              dashArray: [5, 5],
            );
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: chartData.map((entry) {
          return BarChartGroupData(
            x: entry.dayIndex,
            barRods: [
              BarChartRodData(
                toY: entry.minutes,
                width: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
