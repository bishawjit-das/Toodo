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
  notificationService.onCompleteTask = (taskId) =>
      taskRepo.completeTask(taskId);
  await notificationService.init();
  await notificationService.handleLaunchFromNotification();
  final settingsRepo = SettingsRepository(prefs);
  final themeModeNotifier = ValueNotifier<ThemeMode>(settingsRepo.themeMode);
  final accentColorNotifier = ValueNotifier<Color>(settingsRepo.accentColor);
  runApp(
    RepositoryScope(
      listRepository: listRepo,
      taskRepository: taskRepo,
      notificationService: notificationService,
      settingsRepository: settingsRepo,
      themeModeNotifier: themeModeNotifier,
      accentColorNotifier: accentColorNotifier,
      child: MainApp(
        themeModeNotifier: themeModeNotifier,
        accentColorNotifier: accentColorNotifier,
      ),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({
    super.key,
    required this.themeModeNotifier,
    required this.accentColorNotifier,
  });

  final ValueNotifier<ThemeMode> themeModeNotifier;
  final ValueNotifier<Color> accentColorNotifier;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([themeModeNotifier, accentColorNotifier]),
      builder: (_, _) {
        final accent = accentColorNotifier.value;
        return MaterialApp.router(
          title: 'Toodo',
          theme: appTheme(accent),
          darkTheme: appThemeDark(accent),
          themeMode: themeModeNotifier.value,
          debugShowCheckedModeBanner: false,
          routerConfig: createAppRouter(),
        );
      },
    );
  }
}
