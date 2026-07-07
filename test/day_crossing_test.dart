// Tests de regresión del reparto de tiempo entre días (TimeEntry)
// cuando el cronómetro de una tarea cruza la medianoche.

import 'dart:io';

import 'package:estimate_time/models/project.dart';
import 'package:estimate_time/models/task.dart';
import 'package:estimate_time/models/time_entry.dart';
import 'package:estimate_time/providers/task_provider.dart';
import 'package:estimate_time/services/isar_service.dart';
import 'package:estimate_time/utils/date.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

void main() {
  late Directory tempDir;
  late Isar isar;
  late IsarService isarService;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('estimate_time_test');
    isar = await Isar.open(
      [TaskSchema, ProjectSchema, TimeEntrySchema],
      directory: tempDir.path,
      name: 'test_${DateTime.now().microsecondsSinceEpoch}',
      inspector: false,
    );
    isarService = IsarService.withDb(Future.value(isar));
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    await tempDir.delete(recursive: true);
  });

  /// Espera hasta que se cumpla [condition] o falla por timeout
  Future<void> waitUntil(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final end = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(end)) {
        fail('Timeout esperando la condición');
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  List<TimeEntry> sortedEntries(Task task) => task.timeHistory.toList()..sort();

  test('pausar tras cruzar la medianoche reparte el tiempo entre los días',
      () async {
    final provider = TaskProvider(isarService);
    await provider.loadTasks();

    final task = await provider.createTask('Tarea', '', null, null);

    // Simula que el cronómetro quedó corriendo desde ayer a las 23:00
    // sin ticks (app suspendida en segundo plano)
    final DateTime today = DateTime.now().toDate();
    final DateTime yesterday23 =
        today.subtract(const Duration(days: 1)).add(const Duration(hours: 23));

    task.isRunning = true;
    task.lastUpdated = yesterday23;

    await provider.pauseTimer(task);

    final entries = sortedEntries(task);

    expect(entries.length, 2,
        reason: 'El tiempo debe repartirse entre ayer y hoy');

    // Ayer: de 23:00 a 00:00 = 1 hora exacta
    expect(entries[0].day, today.subtract(const Duration(days: 1)));
    expect(entries[0].milliseconds, const Duration(hours: 1).inMilliseconds);

    // Hoy: desde las 00:00 hasta ahora
    expect(entries[1].day, today);
    final int sinceMidnight = DateTime.now().difference(today).inMilliseconds;
    expect(entries[1].milliseconds, closeTo(sinceMidnight, 5000));

    // El total debe ser consistente con la suma de los días
    expect(task.totalTimeMillis,
        entries[0].milliseconds + entries[1].milliseconds);

    provider.dispose();
  });

  test('reanudar la app varios días después registra las 24h de cada día',
      () async {
    final setupProvider = TaskProvider(isarService);
    await setupProvider.loadTasks();

    final task = await setupProvider.createTask('Tarea', '', null, null);

    // Simula que el cronómetro quedó corriendo desde hace 3 días a las 22:00
    // y la app se cerró (sin ticks desde entonces)
    final DateTime today = DateTime.now().toDate();
    final DateTime threeDaysAgo22 =
        today.subtract(const Duration(days: 3)).add(const Duration(hours: 22));

    task.isRunning = true;
    task.lastUpdated = threeDaysAgo22;
    await setupProvider.updateTask(task);

    setupProvider.dispose();

    // Nueva instancia del provider (equivale a abrir la app de nuevo)
    final provider = TaskProvider(isarService);

    // Espera a que se carguen las tareas y se reanuden los cronómetros
    await waitUntil(() =>
        provider.tasks.isNotEmpty &&
        provider.tasks.first.timeHistory.length == 4);

    final Task resumedTask = provider.tasks.first;
    final entries = sortedEntries(resumedTask);

    // Hace 3 días: de 22:00 a 00:00 = 2 horas exactas
    expect(entries[0].day, today.subtract(const Duration(days: 3)));
    expect(entries[0].milliseconds, const Duration(hours: 2).inMilliseconds);

    // Días intermedios completos: 24 horas exactas
    expect(entries[1].day, today.subtract(const Duration(days: 2)));
    expect(entries[1].milliseconds, const Duration(hours: 24).inMilliseconds);

    expect(entries[2].day, today.subtract(const Duration(days: 1)));
    expect(entries[2].milliseconds, const Duration(hours: 24).inMilliseconds);

    // Hoy: desde las 00:00 hasta ahora
    expect(entries[3].day, today);
    final int sinceMidnight = DateTime.now().difference(today).inMilliseconds;
    expect(entries[3].milliseconds, closeTo(sinceMidnight, 5000));

    provider.dispose();
  });

  test('setTodayTime invalida el todayTimeEntry de un día anterior', () async {
    final provider = TaskProvider(isarService);
    await provider.loadTasks();

    final task = await provider.createTask('Tarea', '', null, null);

    // Entrada de tiempo de ayer
    final DateTime yesterday = DateTime.now().subtract(const Duration(days: 1));
    final TimeEntry yesterdayEntry =
        TimeEntry.ofDuration(yesterday, const Duration(hours: 1));

    await isar.writeTxn(() async {
      await isar.timeEntries.put(yesterdayEntry);
      task.timeHistory.add(yesterdayEntry);
      await task.timeHistory.save();
    });

    // Simula que todayTimeEntry quedó apuntando a la entrada de ayer
    // (la app permaneció abierta al pasar la medianoche)
    task.todayTimeEntry = yesterdayEntry;

    provider.setTodayTime(task);

    expect(task.todayTimeEntry, isNull,
        reason: 'El todayTimeEntry de un día anterior debe invalidarse');
    expect(task.todayTime, isNull);

    // Con una entrada de hoy, setTodayTime debe asignarla
    final TimeEntry todayEntry =
        TimeEntry.ofDuration(DateTime.now(), const Duration(minutes: 30));

    await isar.writeTxn(() async {
      await isar.timeEntries.put(todayEntry);
      task.timeHistory.add(todayEntry);
      await task.timeHistory.save();
    });

    provider.setTodayTime(task);

    expect(task.todayTimeEntry?.id, todayEntry.id);

    provider.dispose();
  });
}
