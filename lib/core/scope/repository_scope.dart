import 'package:flutter/material.dart';
import 'package:toodo/core/notifications/notification_service.dart';
import 'package:toodo/core/settings/settings_repository.dart';
import 'package:toodo/data/repositories/list_repository.dart';
import 'package:toodo/data/repositories/task_repository.dart';

class RepositoryScope extends InheritedWidget {
  const RepositoryScope({
    super.key,
    required this.listRepository,
    required this.taskRepository,
    required this.notificationService,
    this.settingsRepository,
    this.themeModeNotifier,
    this.accentColorNotifier,
    required super.child,
  });

  final ListRepository listRepository;
  final TaskRepository taskRepository;
  final NotificationService notificationService;
  final SettingsRepository? settingsRepository;
  final ValueNotifier<ThemeMode>? themeModeNotifier;
  final ValueNotifier<Color>? accentColorNotifier;

  static RepositoryScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RepositoryScope>();
    assert(scope != null, 'No RepositoryScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(RepositoryScope oldWidget) =>
      listRepository != oldWidget.listRepository ||
      taskRepository != oldWidget.taskRepository ||
      notificationService != oldWidget.notificationService ||
      settingsRepository != oldWidget.settingsRepository ||
      themeModeNotifier != oldWidget.themeModeNotifier ||
      accentColorNotifier != oldWidget.accentColorNotifier;
}
