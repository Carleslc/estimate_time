final hourInMinutes = Duration.minutesPerHour.toDouble();

extension DurationFormat on Duration {
  static String padLeft(int n, int width) => n.toString().padLeft(width, '0');
  static String twoDigits(int n) => padLeft(n, 2);

  String formatTime({bool withSeconds = true, bool withSecondsPart = false}) {
    var (hours, minutes, remainingSeconds) = _timeParts();

    String formatted = '${twoDigits(hours)}:${twoDigits(minutes)}';

    if (withSeconds) {
      formatted += ':';
      if (withSecondsPart) {
        int seconds = remainingSeconds.truncate();
        int fraction = ((remainingSeconds - seconds) * 100).round();
        formatted += '${twoDigits(seconds)}.${twoDigits(fraction)}';
      } else {
        int seconds = remainingSeconds.truncate();
        formatted += twoDigits(seconds);
      }
    }

    return formatted;
  }

  String format({bool withSeconds = true}) {
    var (hours, minutes, remainingSeconds) = _timeParts();

    String formatted = '';
    if (hours > 0) {
      formatted += ' $hours h';
    }
    if (minutes > 0) {
      formatted += ' $minutes min';
    }
    if (withSeconds) {
      int seconds = remainingSeconds.truncate();

      if (seconds > 0 || formatted.isEmpty) {
        formatted += ' $seconds s';
      }
    }

    return formatted.trim();
  }

  double get totalSeconds => inMicroseconds / Duration.microsecondsPerSecond;

  double get totalMinutes => inMicroseconds / Duration.microsecondsPerMinute;

  double get totalHours => inMicroseconds / Duration.microsecondsPerHour;

  (int hours, int minutes, double seconds) _timeParts() {
    double remainderSeconds = totalSeconds;
    // entire hours
    int hours = remainderSeconds ~/ Duration.secondsPerHour;
    remainderSeconds -= hours * Duration.secondsPerHour;
    // entire minutes
    int minutes = remainderSeconds ~/ Duration.secondsPerMinute;
    // remaining seconds
    remainderSeconds -= minutes * Duration.secondsPerMinute;
    return (hours, minutes, remainderSeconds);
  }

  Duration roundToSecond() => Duration(seconds: roundToSeconds());

  /// Equivalent to `roundToSecond().inSeconds`, but without wrapping a Duration.\
  /// Result is in seconds.
  int roundToSeconds() =>
      (inMicroseconds / Duration.microsecondsPerSecond).round();

  /// Equivalent to `roundToSecond().inMilliseconds`, but without wrapping a Duration.\
  /// Result is in milliseconds.
  int roundToSecondMillis() =>
      roundToSeconds() * Duration.millisecondsPerSecond;

  /// Equivalent to `Duration(milliseconds: millis).roundToSecondMillis()`, but without wrapping a Duration.\
  /// Result is in milliseconds.
  static int roundMillisToSecond(int millis) =>
      Duration.millisecondsPerSecond *
      (millis / Duration.millisecondsPerSecond).round();
}
