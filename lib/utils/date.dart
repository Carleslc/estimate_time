import 'package:intl/intl.dart';

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

final _isSameDay = isSameDay;

extension TimeFormatter on DateTime {
  static final DateFormat timeFormat = DateFormat.Hm();
  static final DateFormat dateFormat = DateFormat.yMEd();
  static final DateFormat dateFormatMEd = DateFormat.MMMEd();
  static final DateFormat timeDateFormat = timeFormat.addPattern('yMEd', '  ');

  String formatFutureTime({bool round = true}) {
    DateTime roundDate =
        round && second > 30 ? copyWith(minute: minute + 1, second: 0) : this;
    return roundDate.isSameDay(DateTime.now())
        ? roundDate.formatTime()
        : timeDateFormat.format(roundDate);
  }

  String formatTime() => timeFormat.format(this);

  String formatDate() => dateFormat.format(this);

  String formatDateMEd() => dateFormatMEd.format(this);

  bool isSameDay(DateTime other) => _isSameDay(this, other);
}
