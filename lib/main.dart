import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

class MainApp extends StatefulWidget {
  const MainApp({
    super.key,
    required this.themeModeNotifier,
    required this.accentColorNotifier,
  });

  final ValueNotifier<ThemeMode> themeModeNotifier;
  final ValueNotifier<Color> accentColorNotifier;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late Future<void> _fontLoader;

  @override
  void initState() {
    super.initState();
    _fontLoader = _prepareFonts().timeout(
      const Duration(seconds: 3),
      onTimeout: () {},
    );
  }

  Future<void> _prepareFonts() async {
    appTheme();
    appThemeDark();
    await GoogleFonts.pendingFonts();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.themeModeNotifier,
        widget.accentColorNotifier,
      ]),
      builder: (context, _) {
        final accent = widget.accentColorNotifier.value;
        final mode = widget.themeModeNotifier.value;

        return FutureBuilder(
          future: _fontLoader,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return MaterialApp(
                home: Scaffold(
                  appBar: AppBar(),
                  body: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                theme: appTheme(accent),
                darkTheme: appThemeDark(accent),
                themeMode: mode,
                debugShowCheckedModeBanner: false,
              );
            }

            return MaterialApp.router(
              title: 'Toodo',
              theme: appTheme(accent),
              darkTheme: appThemeDark(accent),
              themeMode: mode,
              debugShowCheckedModeBanner: false,
              routerConfig: createAppRouter(),
            );
          },
        );
      },
    );
  }
}
