import 'package:flutter/material.dart';
import 'package:toodo/data/repositories/list_repository.dart';
import 'package:toodo/data/repositories/task_repository.dart';

class RepositoryScope extends InheritedWidget {
  const RepositoryScope({
    super.key,
    required this.listRepository,
    required this.taskRepository,
    required super.child,
  });

  final ListRepository listRepository;
  final TaskRepository taskRepository;

  static RepositoryScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RepositoryScope>();
    assert(scope != null, 'No RepositoryScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(RepositoryScope oldWidget) =>
      listRepository != oldWidget.listRepository ||
      taskRepository != oldWidget.taskRepository;
}
