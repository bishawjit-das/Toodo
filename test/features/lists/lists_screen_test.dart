import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toodo/core/scope/repository_scope.dart';
import 'package:toodo/data/database/app_database.dart';
import 'package:toodo/data/repositories/list_repository.dart';
import 'package:toodo/data/repositories/task_repository.dart';
import 'package:toodo/features/lists/lists_screen.dart';

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

  Widget wrapWithScope(Widget child) {
    return RepositoryScope(
      listRepository: listRepo,
      taskRepository: taskRepo,
      child: MaterialApp(home: child),
    );
  }

  group('ListsScreen', () {
    testWidgets('shows lists from repository', (tester) async {
      await listRepo.insertList('Work');
      await listRepo.insertList('Personal');
      await tester.pumpWidget(wrapWithScope(const ListsScreen()));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('drawer_menu')));
      await tester.pumpAndSettle();

      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);
    });

    testWidgets('create list: add then list is in repository', (tester) async {
      await tester.pumpWidget(wrapWithScope(const ListsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'New List');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      final lists = await listRepo.getLists();
      expect(lists.map((l) => l.name), contains('New List'));
    });

    testWidgets('rename list: long-press then change name', (tester) async {
      await listRepo.insertList('Old');
      await tester.pumpWidget(wrapWithScope(const ListsScreen()));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('drawer_menu')));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Old'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Renamed');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Renamed'), findsOneWidget);
      expect(find.text('Old'), findsNothing);
    });

    testWidgets('delete list: long-press then delete removes from drawer', (tester) async {
      await listRepo.insertList('Gone');
      await tester.pumpWidget(wrapWithScope(const ListsScreen()));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('drawer_menu')));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Gone'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete')); // confirm
      await tester.pumpAndSettle();

      expect(find.text('Gone'), findsNothing);
    });
  });
}
