class ChartData {
  final List<ChartPoint> points;
  final List<ChartLabel> labels;

  ChartData({
    required this.points,
    required this.labels,
  });
}

class ChartLabel {
  final String label;
  final DateTime value;

  ChartLabel({required this.label, required this.value});
}

class ChartPoint {
  final int dayIndex;
  double minutes;

  ChartPoint({required this.dayIndex, required this.minutes});
}
