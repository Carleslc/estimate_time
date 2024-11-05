import 'package:intl/intl.dart';

extension DateExtension on DateTime {
  DateTime toDate() => DateTime(year, month, day);

  bool isSameDay(DateTime other) => _isSameDay(this, other);

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

extension TimeFormatter on DateTime {
  static final DateFormat timeFormat = DateFormat.Hm();
  static final DateFormat timeFormatSeconds = DateFormat.Hms();
  static final DateFormat dateFormat = DateFormat.yMEd();
  static final DateFormat dateFormatMEd = DateFormat.MMMEd();
  static final DateFormat timeDateFormat = timeFormat.addPattern('yMEd', '  ');

  String formatTimeFuture({bool withSeconds = false, bool round = false}) {
    DateTime roundDate =
        round && second > 30 ? copyWith(minute: minute + 1, second: 0) : this;
    return roundDate.isSameDay(DateTime.now())
        ? roundDate.formatTime(withSeconds: withSeconds)
        : timeDateFormat.format(roundDate);
  }

  String formatTime({bool withSeconds = true}) =>
      withSeconds ? timeFormatSeconds.format(this) : timeFormat.format(this);

  String formatDate() => dateFormat.format(this);

  String formatDateMEd() => dateFormatMEd.format(this);
}
