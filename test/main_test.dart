import 'package:flutter_test/flutter_test.dart';
import 'package:toodo/core/scope/repository_scope.dart';
import 'package:toodo/data/database/app_database.dart';
import 'package:toodo/data/repositories/list_repository.dart';
import 'package:toodo/data/repositories/task_repository.dart';
import 'package:toodo/main.dart';

void main() {
  testWidgets('MainApp builds with router and lists', (tester) async {
    final db = AppDatabase.inMemory();
    final listRepo = ListRepository(db);
    final taskRepo = TaskRepository(db);
    await tester.pumpWidget(RepositoryScope(
      listRepository: listRepo,
      taskRepository: taskRepo,
      child: const MainApp(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('All'), findsOneWidget);
  });
}
