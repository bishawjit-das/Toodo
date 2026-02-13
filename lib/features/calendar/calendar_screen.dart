import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:toodo/core/scope/repository_scope.dart';
import 'package:toodo/data/database/app_database.dart';

/// Tasks grouped by due date (date only). Uses watchAllTasks and filters to tasks with dueDate.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  StreamSubscription<List<Task>>? _sub;
  final Signal<List<Task>> _tasksSignal = signal<List<Task>>([]);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final taskRepo = RepositoryScope.of(context).taskRepository;
    _sub?.cancel();
    _sub = taskRepo.watchAllTasks().listen((list) {
      _tasksSignal.value = list.where((t) => t.dueDate != null).toList();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Calendar'),
      ),
      body: Watch((context) {
        final tasks = _tasksSignal.value;
        final byDate = <String, List<Task>>{};
        for (final t in tasks) {
          final key = _dateKey(t.dueDate!);
          byDate.putIfAbsent(key, () => []).add(t);
        }
        final dates = byDate.keys.toList()..sort();
        if (dates.isEmpty) {
          return const Center(child: Text('No tasks with due dates'));
        }
        return ListView.builder(
          itemCount: dates.length,
          itemBuilder: (context, index) {
            final dateKey = dates[index];
            final dayTasks = byDate[dateKey]!;
            final date = dayTasks.first.dueDate!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    _formatDate(date),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                ...dayTasks.map((t) => ListTile(
                      title: Text(
                        t.title,
                        style: TextStyle(
                          decoration: t.completedAt != null ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      onTap: () => context.go('/'),
                    )),
              ],
            );
          },
        );
      }),
    );
  }
}
