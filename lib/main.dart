import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toodo/core/notifications/notification_service.dart';
import 'package:toodo/core/router/app_router.dart';
import 'package:toodo/core/scope/repository_scope.dart';
import 'package:toodo/core/settings/settings_repository.dart';
import 'package:toodo/core/theme/app_theme.dart';
import 'package:toodo/data/database/app_database.dart';
import 'package:toodo/data/repositories/list_repository.dart';
import 'package:toodo/data/repositories/task_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase();
  final listRepo = ListRepository(db);
  final taskRepo = TaskRepository(db);
  final notificationService = NotificationService();
  notificationService.onCompleteTask = (taskId) => taskRepo.completeTask(taskId);
  await notificationService.init();
  await notificationService.handleLaunchFromNotification();
  final settingsRepo = SettingsRepository(prefs);
  final themeModeNotifier = ValueNotifier<ThemeMode>(settingsRepo.themeMode);
  runApp(RepositoryScope(
    listRepository: listRepo,
    taskRepository: taskRepo,
    notificationService: notificationService,
    settingsRepository: settingsRepo,
    themeModeNotifier: themeModeNotifier,
    child: MainApp(themeModeNotifier: themeModeNotifier),
  ));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, required this.themeModeNotifier});

  final ValueNotifier<ThemeMode> themeModeNotifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (_, themeMode, _) => MaterialApp.router(
        title: 'Toodo',
        theme: appTheme,
        darkTheme: appThemeDark,
        themeMode: themeMode,
        debugShowCheckedModeBanner: false,
        routerConfig: createAppRouter(),
      ),
    );
  }
}
