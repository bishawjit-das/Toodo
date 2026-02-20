import 'package:drift/drift.dart';
import 'package:toodo/data/database/app_database.dart';

/// Seeds the database with up to 10 lists and 50 tasks (variations: due date/time,
/// reminder, repeat, priority, completed, trash, notes, subtasks).
Future<void> seedDatabase(AppDatabase db) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final listNames = [
    'Inbox',
    'Work',
    'Personal',
    'Shopping',
    'Health',
    'Learning',
    'Finance',
    'Travel',
    'Ideas',
    'Later',
  ];
  final listColors = [
    null,
    '#1976D2',
    '#388E3C',
    '#F57C00',
    '#E64A19',
    '#7B1FA2',
    '#00796B',
    '#5D4037',
    '#C2185B',
    '#455A64',
  ];

  final listIds = <int>[];
  for (var i = 0; i < listNames.length; i++) {
    final id = await db.into(db.lists).insert(
          ListsCompanion.insert(
            name: listNames[i],
            color: listColors[i] != null
                ? Value(listColors[i])
                : const Value.absent(),
            sortOrder: Value(i),
          ),
        );
    listIds.add(id);
  }

  int taskCount = 0;
  const maxTasks = 50;
  int sortOrder = 0;

  int listIndex(int offset) => offset % listIds.length;

  Future<int> insertTask({
    required int listId,
    required String title,
    String? notes,
    DateTime? dueDate,
    String? dueTime,
    DateTime? reminder,
    String? repeat,
    int priority = 0,
    DateTime? completedAt,
    DateTime? deletedAt,
    int? parentId,
  }) async {
    final id = await db.into(db.tasks).insert(
          TasksCompanion.insert(
            listId: listId,
            title: title,
            notes: notes != null ? Value(notes) : const Value.absent(),
            dueDate: dueDate != null ? Value(dueDate) : const Value.absent(),
            dueTime: dueTime != null ? Value(dueTime) : const Value.absent(),
            reminder: reminder != null ? Value(reminder) : const Value.absent(),
            repeat: repeat != null ? Value(repeat) : const Value.absent(),
            priority: Value(priority),
            completedAt: completedAt != null
                ? Value(completedAt)
                : const Value.absent(),
            deletedAt: deletedAt != null
                ? Value(deletedAt)
                : const Value.absent(),
            sortOrder: Value(sortOrder++),
            parentId: parentId != null ? Value(parentId) : const Value.absent(),
          ),
        );
    taskCount++;
    return id;
  }

  final listId = listIds[0];

  await insertTask(listId: listId, title: 'Simple task');
  await insertTask(
    listId: listId,
    title: 'Task with notes',
    notes: 'Some extra details here.',
  );
  await insertTask(
    listId: listIds[listIndex(1)],
    title: 'Due today',
    dueDate: today,
  );
  await insertTask(
    listId: listIds[listIndex(2)],
    title: 'Due with time',
    dueDate: today.add(const Duration(days: 1)),
    dueTime: '09:00',
  );
  await insertTask(
    listId: listIds[listIndex(3)],
    title: 'Past due',
    dueDate: today.subtract(const Duration(days: 2)),
  );
  await insertTask(
    listId: listIds[listIndex(4)],
    title: 'With reminder',
    dueDate: today.add(const Duration(days: 3)),
    reminder: today.add(const Duration(days: 3, hours: -1)),
  );
  await insertTask(
    listId: listIds[listIndex(5)],
    title: 'Repeats daily',
    repeat: 'daily',
    dueDate: today,
  );
  await insertTask(
    listId: listIds[listIndex(6)],
    title: 'Repeats weekly',
    repeat: 'weekly',
    dueDate: today.add(const Duration(days: 7)),
  );
  await insertTask(
    listId: listIds[listIndex(7)],
    title: 'High priority',
    priority: 3,
  );
  await insertTask(
    listId: listIds[listIndex(8)],
    title: 'Medium priority',
    priority: 2,
  );
  await insertTask(
    listId: listIds[listIndex(9)],
    title: 'Low priority',
    priority: 1,
  );
  await insertTask(
    listId: listId,
    title: 'Completed task',
    completedAt: now.subtract(const Duration(hours: 1)),
  );
  await insertTask(
    listId: listIds[listIndex(1)],
    title: 'Another completed',
    completedAt: now.subtract(const Duration(days: 1)),
  );
  await insertTask(
    listId: listIds[listIndex(2)],
    title: 'Trashed task',
    deletedAt: now.subtract(const Duration(hours: 2)),
  );
  await insertTask(
    listId: listIds[listIndex(3)],
    title: 'Old trashed',
    deletedAt: now.subtract(const Duration(days: 2)),
  );

  final parentId = await insertTask(
    listId: listIds[listIndex(4)],
    title: 'Task with subtasks',
    notes: 'Parent task.',
  );
  if (taskCount < maxTasks) {
    await insertTask(
      listId: listIds[listIndex(4)],
      title: 'First subtask',
      parentId: parentId,
    );
    await insertTask(
      listId: listIds[listIndex(4)],
      title: 'Second subtask',
      parentId: parentId,
    );
  }

  final parentId2 = await insertTask(
    listId: listIds[listIndex(5)],
    title: 'Another parent',
    dueDate: today.add(const Duration(days: 5)),
  );
  if (taskCount < maxTasks) {
    await insertTask(
      listId: listIds[listIndex(5)],
      title: 'Child A',
      parentId: parentId2,
    );
  }

  while (taskCount < maxTasks) {
    final i = taskCount % listIds.length;
    final titles = [
      'Review notes',
      'Call back',
      'Send email',
      'Read doc',
      'Update list',
      'Check inbox',
      'Plan week',
      'Clean up',
      'Follow up',
      'Schedule meeting',
    ];
    await insertTask(
      listId: listIds[i],
      title: titles[taskCount % titles.length],
      notes: taskCount % 3 == 0 ? 'Note for task ${taskCount + 1}' : null,
      dueDate:
          taskCount % 4 == 0 ? today.add(Duration(days: taskCount)) : null,
      priority: taskCount % 4,
    );
  }
}
