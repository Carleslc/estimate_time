import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/project.dart';
import '../models/task.dart';

class IsarService {
  late Future<Isar> db;

  IsarService() {
    db = _openDB();
  }

  Future<Isar> _openDB() async {
    final dir = await getApplicationDocumentsDirectory();

    return await Isar.open(
      [TaskSchema, ProjectSchema, TimeEntrySchema],
      directory: dir.path,
      inspector: true, // Habilita el inspector de Isar si es necesario
    );
  }
}
