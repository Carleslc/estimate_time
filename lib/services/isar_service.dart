import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../models/time_entry.dart';

class IsarService {
  late Future<Isar> db;

  IsarService() {
    db = _openDB();
  }

  /// Instancia con una base de datos ya abierta (tests)
  IsarService.withDb(this.db);

  Future<Isar> _openDB() async {
    final dir = await getApplicationDocumentsDirectory();

    return await Isar.open(
      [TaskSchema, ProjectSchema, TimeEntrySchema],
      directory: dir.path,
      inspector: true, // Habilita el inspector de Isar si es necesario
    );
  }
}
