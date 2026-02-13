import 'package:flutter/material.dart';
import 'package:toodo/core/router/app_router.dart';
import 'package:toodo/core/theme/app_theme.dart';

void main() {
  runApp(const MainApp());
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
      routerConfig: createAppRouter(),
    );
  }
}
