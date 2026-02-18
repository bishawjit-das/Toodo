import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

@DataClassName('ListRow')
class Lists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get color => text().nullable()();
  IntColumn get icon => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get listId => integer().references(Lists, #id)();
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get dueTime => text().nullable()();
  DateTimeColumn get reminder => dateTime().nullable()();
  TextColumn get repeat => text().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get parentId => integer().nullable().references(Tasks, #id)();
}

@DriftDatabase(tables: [Lists, Tasks])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openLazy());

  static QueryExecutor _openLazy() {
    return LazyDatabase(() async {
      final file = await databaseFile;
      return NativeDatabase.createInBackground(file);
    });
  }

  /// Path to the DB file (e.g. for background isolate or tests).
  static Future<File> get databaseFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'toodo.db'));
  }

  /// For tests: in-memory database.
  static AppDatabase inMemory() {
    return AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.addColumn(tasks, tasks.deletedAt);
          }
        },
      );
}
