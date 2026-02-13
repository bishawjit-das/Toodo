import 'package:drift/drift.dart';
import 'package:toodo/data/database/app_database.dart';

class TaskRepository {
  TaskRepository(this._db);
  final AppDatabase _db;

  Stream<List<Task>> watchTasksByListId(int listId) {
    return (_db.select(_db.tasks)
          ..where((t) => t.listId.equals(listId) & t.parentId.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.id)]))
        .watch();
  }

  /// All top-level tasks across lists (for "All" view). Excludes subtasks.
  Stream<List<Task>> watchAllTasks() {
    return (_db.select(_db.tasks)
          ..where((t) => t.parentId.isNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .watch();
  }

  Stream<List<Task>> watchSubtasksOf(int parentId) {
    return (_db.select(_db.tasks)
          ..where((t) => t.parentId.equals(parentId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.id)]))
        .watch();
  }

  Future<List<Task>> getSubtasks(int parentId) {
    return (_db.select(_db.tasks)
          ..where((t) => t.parentId.equals(parentId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.id)]))
        .get();
  }

  Future<int> insertTask(
    int listId,
    String title, {
    String? notes,
    DateTime? dueDate,
    String? dueTime,
    DateTime? reminder,
    String? repeat,
    int priority = 0,
    int sortOrder = 0,
    int? parentId,
  }) {
    return _db.into(_db.tasks).insert(
          TasksCompanion.insert(
            listId: listId,
            title: title,
            notes: Value(notes),
            dueDate: Value(dueDate),
            dueTime: Value(dueTime),
            reminder: Value(reminder),
            repeat: Value(repeat),
            priority: Value(priority),
            sortOrder: Value(sortOrder),
            parentId: Value(parentId),
          ),
        );
  }

  Future<void> updateTask(
    int id, {
    String? title,
    String? notes,
    DateTime? dueDate,
    String? dueTime,
    DateTime? reminder,
    String? repeat,
    int? priority,
    int? sortOrder,
    DateTime? completedAt,
  }) {
    return (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
          TasksCompanion(
            title: title != null ? Value(title) : const Value.absent(),
            notes: notes != null ? Value(notes) : const Value.absent(),
            dueDate: dueDate != null ? Value(dueDate) : const Value.absent(),
            dueTime: dueTime != null ? Value(dueTime) : const Value.absent(),
            reminder: reminder != null ? Value(reminder) : const Value.absent(),
            repeat: repeat != null ? Value(repeat) : const Value.absent(),
            priority: priority != null ? Value(priority) : const Value.absent(),
            sortOrder: sortOrder != null ? Value(sortOrder) : const Value.absent(),
            completedAt: completedAt != null ? Value(completedAt) : const Value.absent(),
          ),
        );
  }

  Future<void> deleteTask(int id) {
    return (_db.delete(_db.tasks)..where((t) => t.id.equals(id))).go();
  }

  Future<Task?> getTask(int id) {
    return (_db.select(_db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> completeTask(int id) {
    return updateTask(id, completedAt: DateTime.now());
  }

  Future<void> incompleteTask(int id) {
    return (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(const TasksCompanion(completedAt: Value(null)));
  }
}
