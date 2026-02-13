import 'package:toodo/data/database/app_database.dart';
import 'package:toodo/data/repositories/list_repository.dart';
import 'package:toodo/data/repositories/task_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ListRepository listRepo;
  late TaskRepository taskRepo;

  setUp(() {
    db = AppDatabase.inMemory();
    listRepo = ListRepository(db);
    taskRepo = TaskRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('TaskRepository', () {
    late int listId;

    setUp(() async {
      listId = await listRepo.insertList('Default');
    });

    test('watchTasksByListId emits empty list initially', () async {
      final list = await taskRepo.watchTasksByListId(listId).first;
      expect(list, isEmpty);
    });

    test('watchTasksByListId emits tasks after insert', () async {
      await taskRepo.insertTask(listId, 'Task A');
      await taskRepo.insertTask(listId, 'Task B');
      final list = await taskRepo.watchTasksByListId(listId).first;
      expect(list.length, 2);
      expect(list.map((t) => t.title), containsAll(['Task A', 'Task B']));
    });

    test('insertTask returns id', () async {
      final id = await taskRepo.insertTask(listId, 'New');
      expect(id, greaterThan(0));
      final task = await taskRepo.getTask(id);
      expect(task!.title, 'New');
      expect(task.listId, listId);
    });

    test('updateTask changes title', () async {
      final id = await taskRepo.insertTask(listId, 'Old');
      await taskRepo.updateTask(id, title: 'Updated');
      final task = await taskRepo.getTask(id);
      expect(task!.title, 'Updated');
    });

    test('deleteTask removes task', () async {
      final id = await taskRepo.insertTask(listId, 'Gone');
      await taskRepo.deleteTask(id);
      final task = await taskRepo.getTask(id);
      expect(task, equals(null));
    });

    test('getTask returns null for missing id', () async {
      final task = await taskRepo.getTask(999);
      expect(task, equals(null));
    });

    test('completeTask sets completedAt', () async {
      final id = await taskRepo.insertTask(listId, 'Do it');
      await taskRepo.completeTask(id);
      final task = await taskRepo.getTask(id);
      expect(task!.completedAt, isNotNull);
    });

    test('incompleteTask clears completedAt', () async {
      final id = await taskRepo.insertTask(listId, 'Done');
      await taskRepo.completeTask(id);
      await taskRepo.incompleteTask(id);
      final task = await taskRepo.getTask(id);
      expect(task!.completedAt, equals(null));
    });
  });

  group('TaskRepository watchAllTasks', () {
    test('emits tasks from all lists', () async {
      final list1 = await listRepo.insertList('L1');
      final list2 = await listRepo.insertList('L2');
      await taskRepo.insertTask(list1, 'Task 1');
      await taskRepo.insertTask(list2, 'Task 2');
      final all = await taskRepo.watchAllTasks().first;
      expect(all.length, 2);
      expect(all.map((t) => t.title), containsAll(['Task 1', 'Task 2']));
    });

    test('excludes subtasks (parentId not null)', () async {
      final listId = await listRepo.insertList('Default');
      final parentTaskId = await taskRepo.insertTask(listId, 'Parent');
      await taskRepo.insertTask(listId, 'Child', parentId: parentTaskId);
      final all = await taskRepo.watchAllTasks().first;
      expect(all.length, 1);
      expect(all.first.title, 'Parent');
    });
  });
}
