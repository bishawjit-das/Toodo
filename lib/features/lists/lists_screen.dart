import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:toodo/core/notifications/notification_service.dart';
import 'package:toodo/core/scope/repository_scope.dart';
import 'package:toodo/data/database/app_database.dart';
import 'package:toodo/data/repositories/list_repository.dart';
import 'package:toodo/data/repositories/task_repository.dart';

class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  ListRepository? _listRepo;
  TaskRepository? _taskRepo;
  late final Signal<List<ListRow>> _listsSignal = signal<List<ListRow>>([]);
  late final Signal<List<Task>> _tasksSignal = signal<List<Task>>([]);
  StreamSubscription<List<ListRow>>? _sub;
  StreamSubscription<List<Task>>? _taskSub;
  int? _selectedListId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = RepositoryScope.of(context);
    if (_listRepo != scope.listRepository) {
      _sub?.cancel();
      _listRepo = scope.listRepository;
      _sub = _listRepo!.watchLists().listen((data) => _listsSignal.value = data);
    }
    if (_taskRepo != scope.taskRepository) {
      _taskRepo = scope.taskRepository;
    }
    _subscribeToTasks();
  }

  void _subscribeToTasks() {
    _taskSub?.cancel();
    final repo = _taskRepo;
    if (repo == null) return;
    final stream = _selectedListId == null ? repo.watchAllTasks() : repo.watchTasksByListId(_selectedListId!);
    _taskSub = stream.listen((data) => _tasksSignal.value = data);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _taskSub?.cancel();
    super.dispose();
  }

  ListRepository get _repo => _listRepo!;
  TaskRepository get _taskRepository => _taskRepo!;

  int? get _effectiveListId => _selectedListId ?? (_listsSignal.value.isNotEmpty ? _listsSignal.value.first.id : null);

  String _titleFor(int? id) {
    if (id == null) return 'All';
    final match = _listsSignal.value.where((l) => l.id == id);
    return match.isEmpty ? 'List' : match.first.name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            key: const Key('drawer_menu'),
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Watch((context) => Text(_titleFor(_selectedListId))),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddListDialog),
        ],
      ),
      drawer: _buildDrawer(context),
      body: _buildTaskList(),
      floatingActionButton: _effectiveListId != null
          ? FloatingActionButton(
              onPressed: _showAddTaskDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildTaskList() {
    return Watch((context) {
      final tasks = _tasksSignal.value;
      if (tasks.isEmpty) {
        return Center(child: Text(_effectiveListId == null ? 'Select a list to add tasks' : 'No tasks'));
      }
      return ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return ListTile(
            leading: Checkbox(
              value: task.completedAt != null,
              onChanged: (_) => _toggleTask(task),
            ),
            title: Text(
              task.title,
              style: TextStyle(decoration: task.completedAt != null ? TextDecoration.lineThrough : null),
            ),
            subtitle: task.dueDate != null ? Text(_formatDate(task.dueDate!)) : null,
            onTap: () => _showEditTaskSheet(task),
            onLongPress: () => _showTaskOptions(context, task),
          );
        },
      );
    });
  }

  String _formatDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _toggleTask(Task task) {
    if (task.completedAt != null) {
      _taskRepository.incompleteTask(task.id);
    } else {
      _taskRepository.completeTask(task.id);
    }
  }

  void _showAddTaskDialog() {
    final listId = _effectiveListId;
    if (listId == null) return;
    if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
      Navigator.of(context).pop(); // close drawer only if open
    }
    final titleController = TextEditingController();
    DateTime? dueDate;
    DateTime? reminder;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'Task name'),
                  onSubmitted: (_) => _addTask(ctx, listId, titleController.text, dueDate, reminder),
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: Text(dueDate == null ? 'Due date' : _formatDate(dueDate!)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (picked != null) setDialogState(() => dueDate = picked);
                  },
                ),
                ListTile(
                  title: Text(reminder == null ? 'Reminder' : _formatDate(reminder!)),
                  trailing: const Icon(Icons.notifications),
                  onTap: () async {
                    final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (date != null) setDialogState(() => reminder = date);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => _addTask(ctx, listId, titleController.text, dueDate, reminder),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _addTask(BuildContext ctx, int listId, String title, DateTime? dueDate, DateTime? reminder) {
    if (title.trim().isEmpty) return;
    final notificationService = RepositoryScope.of(ctx).notificationService;
    _taskRepository.insertTask(listId, title.trim(), dueDate: dueDate, reminder: reminder).then((id) {
      if (reminder != null) notificationService.scheduleReminder(id, title.trim(), reminder);
    });
    if (ctx.mounted) Navigator.pop(ctx);
  }

  void _showEditTaskSheet(Task task) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _TaskEditSheetContent(
        task: task,
        taskRepo: _taskRepository,
        notificationService: RepositoryScope.of(context).notificationService,
        formatDate: _formatDate,
      ),
    );
  }

  void _showTaskOptions(BuildContext context, Task task) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                _showEditTaskSheet(task);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteTaskConfirm(context, task);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteTaskConfirm(BuildContext context, Task task) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('Delete "${task.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              RepositoryScope.of(context).notificationService.cancelReminder(task.id);
              _taskRepository.deleteTask(task.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.deepPurple),
            child: Text('Toodo', style: TextStyle(color: Colors.white, fontSize: 24)),
          ),
          ListTile(
            title: const Text('All'),
            selected: _selectedListId == null,
            onTap: () {
              setState(() => _selectedListId = null);
              _subscribeToTasks();
            },
          ),
          Watch((context) {
            final lists = _listsSignal.value;
            return Column(
              children: lists
                  .map((list) => ListTile(
                        title: Text(list.name),
                        selected: _selectedListId == list.id,
                        onTap: () {
                          setState(() => _selectedListId = list.id);
                          _subscribeToTasks();
                        },
                        onLongPress: () => _showListOptions(context, list),
                      ))
                  .toList(),
            );
          }),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('Calendar'),
            onTap: () {
              Navigator.pop(context);
              context.go('/calendar');
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              context.go('/settings');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add list'),
            onTap: _showAddListDialog,
          ),
        ],
      ),
    );
  }

  void _showAddListDialog() {
    if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
      Navigator.of(context).pop(); // close drawer only if open
    }
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New list'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'List name'),
          onSubmitted: (_) => _addList(controller.text, ctx),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => _addList(controller.text, ctx), child: const Text('Add')),
        ],
      ),
    );
  }

  void _addList(String name, BuildContext dialogContext) {
    if (name.trim().isEmpty) return;
    _repo.insertList(name.trim());
    if (dialogContext.mounted) Navigator.pop(dialogContext);
  }

  void _showListOptions(BuildContext context, ListRow list) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(list);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteConfirm(context, list);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(ListRow list) {
    final controller = TextEditingController(text: list.name);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename list'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Name'),
          onSubmitted: (_) => _renameList(list.id, controller.text, ctx),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => _renameList(list.id, controller.text, ctx), child: const Text('Save')),
        ],
      ),
    );
  }

  void _renameList(int id, String name, BuildContext dialogContext) {
    if (name.trim().isEmpty) return;
    _repo.updateList(id, name: name.trim());
    if (dialogContext.mounted) Navigator.pop(dialogContext);
  }

  void _showDeleteConfirm(BuildContext context, ListRow list) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete list?'),
        content: Text('Delete "${list.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              _repo.deleteList(list.id);
              if (_selectedListId == list.id) setState(() => _selectedListId = null);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _TaskEditSheetContent extends StatefulWidget {
  const _TaskEditSheetContent({
    required this.task,
    required this.taskRepo,
    required this.notificationService,
    required this.formatDate,
  });

  final Task task;
  final TaskRepository taskRepo;
  final NotificationService notificationService;
  final String Function(DateTime) formatDate;

  @override
  State<_TaskEditSheetContent> createState() => _TaskEditSheetContentState();
}

class _TaskEditSheetContentState extends State<_TaskEditSheetContent> {
  late final TextEditingController _titleController = TextEditingController(text: widget.task.title);
  late final TextEditingController _notesController = TextEditingController(text: widget.task.notes ?? '');
  DateTime? _dueDate;
  DateTime? _reminder;
  List<Task> _subtasks = [];
  final _subtaskController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dueDate = widget.task.dueDate;
    _reminder = widget.task.reminder;
    _loadSubtasks();
  }

  Future<void> _loadSubtasks() async {
    final list = await widget.taskRepo.getSubtasks(widget.task.id);
    if (mounted) setState(() => _subtasks = list);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
              ListTile(
                title: Text(_dueDate == null ? 'Due date' : widget.formatDate(_dueDate!)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _dueDate = picked);
                },
              ),
              ListTile(
                title: Text(_reminder == null ? 'Reminder' : widget.formatDate(_reminder!)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _reminder ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) setState(() => _reminder = date);
                },
              ),
              const Divider(),
              Text('Subtasks', style: Theme.of(context).textTheme.titleSmall),
              ..._subtasks.map((t) => ListTile(
                    title: Text(t.title),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () async {
                        await widget.taskRepo.deleteTask(t.id);
                        _loadSubtasks();
                      },
                    ),
                  )),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subtaskController,
                      decoration: const InputDecoration(hintText: 'Add subtask'),
                      onSubmitted: (_) => _addSubtask(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addSubtask,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      final id = widget.task.id;
                      final title = _titleController.text.trim();
                      widget.notificationService.cancelReminder(id);
                      await widget.taskRepo.updateTask(
                        id,
                        title: title,
                        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
                        dueDate: _dueDate,
                        reminder: _reminder,
                      );
                      if (_reminder != null) {
                        widget.notificationService.scheduleReminder(id, title, _reminder!);
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addSubtask() {
    final title = _subtaskController.text.trim();
    if (title.isEmpty) return;
    widget.taskRepo.insertTask(widget.task.listId, title, parentId: widget.task.id);
    _subtaskController.clear();
    _loadSubtasks();
  }
}
