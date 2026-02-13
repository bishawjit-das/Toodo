import 'package:flutter/material.dart';
import 'package:toodo/core/router/app_router.dart';
import 'package:toodo/core/scope/repository_scope.dart';
import 'package:toodo/core/theme/app_theme.dart';
import 'package:toodo/data/database/app_database.dart';
import 'package:toodo/data/repositories/list_repository.dart';
import 'package:toodo/data/repositories/task_repository.dart';

void main() {
  final db = AppDatabase();
  final listRepo = ListRepository(db);
  final taskRepo = TaskRepository(db);
  runApp(RepositoryScope(
    listRepository: listRepo,
    taskRepository: taskRepo,
    child: const MainApp(),
  ));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Toodo',
      theme: appTheme,
      darkTheme: appThemeDark,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      routerConfig: createAppRouter(),
    );
  }
}
