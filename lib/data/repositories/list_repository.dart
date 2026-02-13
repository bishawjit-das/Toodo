import 'package:drift/drift.dart';
import 'package:toodo/data/database/app_database.dart';

class ListRepository {
  ListRepository(this._db);
  final AppDatabase _db;

  Stream<List<ListRow>> watchLists() {
    return (_db.select(_db.lists)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).watch();
  }

  Future<int> insertList(
    String name, {
    String? color,
    int? icon,
    int sortOrder = 0,
  }) {
    return _db.into(_db.lists).insert(
          ListsCompanion.insert(
            name: name,
            color: Value(color),
            icon: Value(icon),
            sortOrder: Value(sortOrder),
          ),
        );
  }

  Future<void> updateList(
    int id, {
    String? name,
    String? color,
    int? icon,
    int? sortOrder,
  }) {
    return (_db.update(_db.lists)..where((t) => t.id.equals(id))).write(
          ListsCompanion(
            name: name != null ? Value(name) : const Value.absent(),
            color: color != null ? Value(color) : const Value.absent(),
            icon: icon != null ? Value(icon) : const Value.absent(),
            sortOrder: sortOrder != null ? Value(sortOrder) : const Value.absent(),
          ),
        );
  }

  Future<void> deleteList(int id) {
    return (_db.delete(_db.lists)..where((t) => t.id.equals(id))).go();
  }

  Future<ListRow?> getList(int id) {
    return (_db.select(_db.lists)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<ListRow>> getLists() {
    return (_db.select(_db.lists)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();
  }
}
