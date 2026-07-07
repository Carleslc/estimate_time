import 'package:isar_community/isar.dart';

import '../utils/date.dart';
import 'task.dart';

part 'time_entry.g.dart';

@Collection(accessor: 'timeEntries')
class TimeEntry implements Comparable<TimeEntry> {
  Id id = Isar.autoIncrement;

  @Backlink(to: 'timeHistory')
  final task = IsarLink<Task>();

  late DateTime date;

  late int milliseconds;

  TimeEntry(); // Isar needs an empty constructor

  TimeEntry.ofDate(this.date) : milliseconds = 0;

  TimeEntry.ofMillis(this.date, this.milliseconds);

  TimeEntry.ofDuration(this.date, Duration duration)
      : milliseconds = duration.inMilliseconds;

  @ignore
  int get seconds => duration.inSeconds;

  @ignore
  Duration get duration => Duration(milliseconds: milliseconds);

  set duration(Duration duration) {
    milliseconds = duration.inMilliseconds;
  }

  @ignore
  DateTime get day => date.toDate();

  @override
  int compareTo(TimeEntry other) => date.compareTo(other.date);

  @override
  String toString() => 'TimeEntry(id: $id, date: $date, duration: $duration)';
}
