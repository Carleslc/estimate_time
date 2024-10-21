extension DurationFormatting on Duration {
  static String twoDigits(int n) => n.toString().padLeft(2, '0');

  String formatTime({bool withSeconds = true}) {
    final hours = twoDigits(inHours);
    final minutes = twoDigits(inMinutes.remainder(60));

    String formatted = '$hours:$minutes';
    if (withSeconds) {
      final seconds = twoDigits(inSeconds.remainder(60));
      formatted += ':$seconds';
    }
    return formatted;
  }

  String format({bool withSeconds = true}) {
    final hours = inHours;
    final minutes = inMinutes.remainder(60);
    final seconds = inSeconds.remainder(60);

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
}
