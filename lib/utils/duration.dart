final hourInMinutes = Duration.minutesPerHour.toDouble();

extension DurationFormatting on Duration {
  static String twoDigits(int n) => n.toString().padLeft(2, '0');

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

  Duration roundToSecond() {
    int ms = Duration.microsecondsPerSecond;
    int timeSeconds = (inMicroseconds / ms).truncate();
    int roundedSecond = ((inMicroseconds % ms) / ms).round();
    return Duration(microseconds: (timeSeconds + roundedSecond) * ms);
  }
}
