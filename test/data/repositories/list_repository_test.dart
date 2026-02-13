import 'package:toodo/data/database/app_database.dart';
import 'package:toodo/data/repositories/list_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ListRepository repo;

  setUp(() {
    db = AppDatabase.inMemory();
    repo = ListRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('ListRepository', () {
    test('watchLists emits empty list initially', () async {
      final list = await repo.watchLists().first;
      expect(list, isEmpty);
    });

    test('watchLists emits lists after insert', () async {
      await repo.insertList('Work');
      await repo.insertList('Personal');
      final list = await repo.watchLists().first;
      expect(list.length, 2);
      expect(list.map((r) => r.name), containsAll(['Work', 'Personal']));
    });

    test('insertList returns id and assigns sortOrder', () async {
      final id = await repo.insertList('Inbox');
      expect(id, greaterThan(0));
      final list = await repo.getList(id);
      expect(list!.name, 'Inbox');
      expect(list.sortOrder, 0);
    });

    test('updateList changes name', () async {
      final id = await repo.insertList('Old');
      await repo.updateList(id, name: 'New');
      final list = await repo.getList(id);
      expect(list!.name, 'New');
    });

    test('deleteList removes list', () async {
      final id = await repo.insertList('Gone');
      await repo.deleteList(id);
      final list = await repo.getList(id);
      expect(list, equals(null));
    });

    test('getList returns null for missing id', () async {
      final list = await repo.getList(999);
      expect(list, equals(null));
    });
  });
}
