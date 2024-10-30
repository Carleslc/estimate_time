import 'package:isar/isar.dart';

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
