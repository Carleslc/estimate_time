import 'package:isar/isar.dart';

import '../utils/date.dart';

part 'time_entry.g.dart';

@Collection(accessor: 'timeEntries')
class TimeEntry {
  Id id = Isar.autoIncrement;

  late DateTime date;

  late int milliseconds;

  @ignore
  int get seconds => duration.inSeconds;

  @ignore
  Duration get duration => Duration(milliseconds: milliseconds);

  @ignore
  DateTime get day => date.toDate();

  @override
  String toString() => 'TimeEntry(id: $id, date: $date, duration: $duration)';
}
