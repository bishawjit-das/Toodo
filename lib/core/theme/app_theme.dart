import 'package:flutter/material.dart';

ThemeData get appTheme => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
      typography: Typography.material2021(),
    );

ThemeData get appThemeDark => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
      typography: Typography.material2021(),
    );
