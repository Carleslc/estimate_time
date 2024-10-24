final hourInMinutes = Duration.minutesPerHour.toDouble();

extension DurationFormatting on Duration {
  static String twoDigits(int n) => n.toString().padLeft(2, '0');

  String formatTime({bool withSeconds = true}) {
    var (hours, minutes, seconds) = _timeParts();

    String formatted = '${twoDigits(hours)}:${twoDigits(minutes)}';

    if (withSeconds) {
      formatted += ':${twoDigits(seconds)}';
    }

    return formatted;
  }

  String format({bool withSeconds = true}) {
    var (hours, minutes, seconds) = _timeParts();

    String formatted = '';
    if (hours > 0) {
      formatted += ' $hours h';
    }
    if (minutes > 0) {
      formatted += ' $minutes min';
    }
    if (withSeconds && seconds > 0) {
      formatted += ' $seconds s';
    }
    return formatted.trim();
  }

  double get totalSeconds => inMicroseconds / Duration.microsecondsPerSecond;

  double get totalMinutes => inMicroseconds / Duration.microsecondsPerMinute;

  double get totalHours => inMicroseconds / Duration.microsecondsPerHour;

  (int hours, int minutes, int seconds) _timeParts() {
    double remainderSeconds = totalSeconds;
    // entire hours
    int hours = remainderSeconds ~/ Duration.secondsPerHour;
    remainderSeconds -= hours * Duration.secondsPerHour;
    // entire minutes
    int minutes = remainderSeconds ~/ Duration.secondsPerMinute;
    remainderSeconds -= minutes * Duration.secondsPerMinute;
    // round seconds
    int seconds = remainderSeconds.truncate();
    return (hours, minutes, seconds);
  }
}
