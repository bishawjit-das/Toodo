import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:toodo/core/notifications/notification_service.dart';
import 'package:toodo/core/scope/repository_scope.dart';
import 'package:toodo/core/settings/settings_repository.dart';
import 'package:toodo/data/database/app_database.dart';
import 'package:toodo/data/repositories/list_repository.dart';
import 'package:toodo/data/repositories/task_repository.dart';

class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

/// Default list name; always exists, cannot be renamed or deleted.
const String _inboxName = 'Inbox';

/// Virtual list keys (app-created, not in DB).
const String _virtualAll = 'all';
const String _virtualToday = 'today';
const String _virtualTomorrow = 'tomorrow';
const String _virtualNext7 = 'next7';
const String _virtualCompleted = 'completed';
const String _virtualTrash = 'trash';

bool _isToday(DateTime d) {
  final n = DateTime.now();
  return d.year == n.year && d.month == n.month && d.day == n.day;
}

bool _isTomorrow(DateTime d) {
  final t = DateTime.now().add(const Duration(days: 1));
  return d.year == t.year && d.month == t.month && d.day == t.day;
}

bool _isInNext7Days(DateTime d) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final end = start.add(const Duration(days: 7));
  return !d.isBefore(start) && d.isBefore(end);
}

class _ListsScreenState extends State<ListsScreen> with WidgetsBindingObserver {
  ListRepository? _listRepo;
  TaskRepository? _taskRepo;
  late final Signal<List<ListRow>> _listsSignal = signal<List<ListRow>>([]);
  late final Signal<List<Task>> _tasksSignal = signal<List<Task>>([]);
  StreamSubscription<List<ListRow>>? _sub;
  StreamSubscription<List<Task>>? _taskSub;
  bool _ignoreNextTaskEmission = false;

  /// Virtual view: 'all', 'today', 'tomorrow', 'next7'. When null, a list is selected.
  String? _selectedVirtualKey = _virtualAll;
  int? _selectedListId;
  bool _inboxEnsured = false;

  /// Name of list just created; used as title until watchLists() emits.
  int? _createdListId;
  String? _createdListName;

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = RepositoryScope.of(context);
    if (_listRepo != scope.listRepository) {
      _sub?.cancel();
      _inboxEnsured = false;
      _listRepo = scope.listRepository;
      _sub = _listRepo!.watchLists().listen((data) {
        if (data.isEmpty && !_inboxEnsured) {
          _inboxEnsured = true;
          _listRepo!.insertList(_inboxName);
        }
        if (_createdListId != null && data.any((l) => l.id == _createdListId)) {
          _createdListId = null;
          _createdListName = null;
        }
        _listsSignal.value = data;
      });
    }
    if (_taskRepo != scope.taskRepository) {
      _taskRepo = scope.taskRepository;
    }
    _subscribeToTasks();
  }

  void _applyTaskFilter(List<Task> data) {
    if (_ignoreNextTaskEmission) {
      _ignoreNextTaskEmission = false;
      return;
    }
    if (_selectedVirtualKey != null) {
      final key = _selectedVirtualKey!;
      if (key == _virtualAll) {
        _tasksSignal.value = data.where((t) => t.completedAt == null).toList();
      } else if (key == _virtualCompleted) {
        _tasksSignal.value = data.where((t) => t.completedAt != null).toList();
      } else if (key == _virtualTrash) {
        _tasksSignal.value = data; // from watchTrashTasks
      } else {
        _tasksSignal.value = data.where((t) {
          if (t.completedAt != null) return false;
          final d = t.dueDate;
          if (d == null) return false;
          if (key == _virtualToday) return _isToday(d);
          if (key == _virtualTomorrow) return _isTomorrow(d);
          if (key == _virtualNext7) return _isInNext7Days(d);
          return false;
        }).toList();
      }
    } else {
      _tasksSignal.value = data.where((t) => t.completedAt == null).toList();
    }
  }

  void _subscribeToTasks() {
    _taskSub?.cancel();
    final repo = _taskRepo;
    if (repo == null) return;
    if (_selectedVirtualKey == _virtualTrash) {
      _taskSub = repo.watchTrashTasks().listen(_applyTaskFilter);
    } else if (_selectedVirtualKey != null) {
      _taskSub = repo.watchAllTasks().listen(_applyTaskFilter);
    } else {
      _taskSub = repo
          .watchTasksByListId(_selectedListId!)
          .listen(_applyTaskFilter);
    }
  }

  /// On resume: read with a fresh DB connection so we see background isolate writes (WAL visibility), then re-subscribe.
  Future<void> _refreshTasksThenResubscribe() async {
    final repo = _taskRepo;
    if (repo == null) return;
    List<Task> data;
    if (_selectedVirtualKey == _virtualTrash) {
      data = await repo.getTrashTasksFresh();
    } else if (_selectedVirtualKey != null) {
      data = await repo.getAllTasksFresh();
    } else {
      final listId = _selectedListId;
      if (listId == null) return;
      data = await repo.getTasksByListIdFresh(listId);
    }
    if (!mounted) return;
    _applyTaskFilter(data);
    _ignoreNextTaskEmission =
        true; // stream's first emission is from main connection (may be stale)
    _subscribeToTasks();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshTasksThenResubscribe();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _taskSub?.cancel();
    super.dispose();
  }

  ListRepository get _repo => _listRepo!;
  TaskRepository get _taskRepository => _taskRepo!;

  /// When a virtual view is selected, new tasks go to Inbox.
  int? get _effectiveListId {
    if (_selectedListId != null) return _selectedListId;
    final lists = _listsSignal.value;
    final inbox = lists.where((l) => l.name == _inboxName).firstOrNull;
    return inbox?.id ?? lists.firstOrNull?.id;
  }

  String _titleFor() {
    if (_selectedVirtualKey != null) {
      switch (_selectedVirtualKey!) {
        case _virtualAll:
          return 'All';
        case _virtualToday:
          return 'Today';
        case _virtualTomorrow:
          return 'Tomorrow';
        case _virtualNext7:
          return 'Next 7 days';
        case _virtualCompleted:
          return 'Completed';
        case _virtualTrash:
          return 'Trash';
        default:
          return 'All';
      }
    }
    final match = _listsSignal.value.where((l) => l.id == _selectedListId);
    if (match.isNotEmpty) return match.first.name;
    if (_selectedListId == _createdListId && _createdListName != null) {
      return _createdListName!;
    }
    return 'List';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          key: const Key('drawer_menu'),
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Watch(
          (context) => Text(_titleFor(), style: TextStyle(fontSize: 18)),
        ),
        actions: [
          IconButton(
            key: const Key('settings'),
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: _buildTaskList(),
      // Show FAB for virtual views (tasks go to Inbox) and when a list is selected.
      floatingActionButton: _selectedVirtualKey != _virtualTrash &&
              (_selectedVirtualKey != null || _effectiveListId != null)
          ? FloatingActionButton(
              onPressed: _showAddTaskSheet,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildTaskList() {
    return Watch((context) {
      final tasks = _tasksSignal.value;
      if (tasks.isEmpty) {
        return const Center(
          child: Text('No tasks', style: TextStyle(fontSize: 16)),
        );
      }
      final isTrash = _selectedVirtualKey == _virtualTrash;
      return ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          final tile = ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            dense: true,
            horizontalTitleGap: 4,
            minLeadingWidth: 32,
            leading: Checkbox(
              value: task.completedAt != null,
              onChanged: isTrash ? null : (_) => _toggleTask(task),
            ),
            title: Text(
              task.title,
              style: TextStyle(
                fontSize: 16,
                decoration: task.completedAt != null
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            subtitle: task.dueDate != null
                ? Text(_formatDueDate(task.dueDate!))
                : null,
            onTap: () => _showEditTaskSheet(task),
            onLongPress: () => _showTaskOptions(context, task),
          );
          if (isTrash) return tile;
          final settings = RepositoryScope.of(context).settingsRepository;
          final leftAction = settings?.leftSwipeAction ?? SwipeAction.trash;
          final rightAction = settings?.rightSwipeAction ?? SwipeAction.edit;
          return Dismissible(
            key: ValueKey(task.id),
            direction: DismissDirection.horizontal,
            confirmDismiss: (direction) async {
              final action = direction == DismissDirection.endToStart ? leftAction : rightAction;
              if (action == SwipeAction.edit) {
                _showEditTaskSheet(task);
                return false;
              }
              if (action == SwipeAction.trash) {
                RepositoryScope.of(context).notificationService.cancelReminder(task.id);
                _taskRepository.softDelete(task.id);
              } else {
                _taskRepository.completeTask(task.id);
              }
              return true;
            },
            background: _swipeBackground(context, rightAction, Alignment.centerLeft, EdgeInsets.only(left: 16)),
            secondaryBackground: _swipeBackground(context, leftAction, Alignment.centerRight, EdgeInsets.only(right: 16)),
            child: tile,
          );
        },
      );
    });
  }

  Widget _swipeBackground(
    BuildContext context,
    SwipeAction action,
    Alignment alignment,
    EdgeInsets padding,
  ) {
    final theme = Theme.of(context).colorScheme;
    final Color bg;
    final Color fg;
    final IconData icon;
    switch (action) {
      case SwipeAction.trash:
        bg = theme.errorContainer;
        fg = theme.onErrorContainer;
        icon = Icons.delete_outline;
        break;
      case SwipeAction.done:
        bg = theme.primaryContainer;
        fg = theme.onPrimaryContainer;
        icon = Icons.check_circle_outline;
        break;
      case SwipeAction.edit:
        bg = theme.tertiaryContainer;
        fg = theme.onTertiaryContainer;
        icon = Icons.edit_outlined;
        break;
    }
    return Container(
      color: bg,
      alignment: alignment,
      padding: padding,
      child: Icon(icon, color: fg),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatDateTime(DateTime d) =>
      '${_formatDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static const _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatDueDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dDate = DateTime(d.year, d.month, d.day);
    final hasTime = d.hour != 0 || d.minute != 0;
    final hour12 = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
    final ampm = d.hour < 12 ? 'am' : 'pm';
    final timeStr = hasTime
        ? ' $hour12:${d.minute.toString().padLeft(2, '0')} $ampm'
        : '';
    if (dDate == today) return 'Today$timeStr';
    if (dDate == tomorrow) return 'Tomorrow$timeStr';
    return '${_monthNames[d.month - 1]} ${d.day}$timeStr';
  }

  void _toggleTask(Task task) {
    if (task.completedAt != null) {
      _taskRepository.incompleteTask(task.id);
    } else {
      _taskRepository.completeTask(task.id);
    }
  }

  void _showAddTaskSheet() {
    final listId = _effectiveListId;
    if (listId == null) return;
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
    final titleController = TextEditingController();
    final notesController = TextEditingController();
    DateTime? dueDate;
    DateTime? reminder;
    Future<Null> pickDueDate(
      BuildContext ctx,
      void Function(void Function()) setSheetState,
    ) async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: dueDate ?? now,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (picked == null) return;
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: dueDate != null
            ? TimeOfDay.fromDateTime(dueDate!)
            : TimeOfDay.fromDateTime(now),
      );
      if (time != null && mounted) {
        setSheetState(
          () => dueDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          ),
        );
      }
    }

    Future<Null> pickReminder(
      BuildContext ctx,
      void Function(void Function()) setSheetState,
    ) async {
      final now = DateTime.now();
      final date = await showDatePicker(
        context: context,
        initialDate: reminder ?? now,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (date == null) return;
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: reminder != null
            ? TimeOfDay.fromDateTime(reminder!)
            : TimeOfDay.fromDateTime(now),
      );
      if (time != null && mounted) {
        setSheetState(
          () => reminder = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          ),
        );
      }
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => Container(
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              16 + MediaQuery.of(ctx).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'What would you like to do?',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    hintStyle: TextStyle(fontSize: 14),
                  ),
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _addTask(
                    ctx,
                    listId,
                    titleController.text,
                    notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                    dueDate,
                    reminder,
                  ),
                ),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    hintText: 'Description',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  maxLines: 2,
                  minLines: 1,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addTask(
                    ctx,
                    listId,
                    titleController.text,
                    notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                    dueDate,
                    reminder,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => pickDueDate(ctx, setSheetState),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              dueDate != null
                                  ? Icons.calendar_today
                                  : Icons.calendar_today_outlined,
                              size: 22,
                              color: dueDate != null
                                  ? Theme.of(ctx).colorScheme.primary
                                  : Theme.of(ctx).colorScheme.onSurfaceVariant,
                            ),
                            if (dueDate != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                _formatDueDate(dueDate!),
                                style: Theme.of(ctx).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(ctx).colorScheme.primary,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => pickReminder(ctx, setSheetState),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              reminder != null
                                  ? Icons.notifications
                                  : Icons.notifications_outlined,
                              size: 22,
                              color: reminder != null
                                  ? Theme.of(ctx).colorScheme.primary
                                  : Theme.of(ctx).colorScheme.onSurfaceVariant,
                            ),
                            if (reminder != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                _formatDueDate(reminder!),
                                style: Theme.of(ctx).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(ctx).colorScheme.primary,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(ctx).colorScheme.primary,
                      ),
                      icon: const Icon(Icons.check, color: Colors.white),
                      tooltip: 'Add task',
                      onPressed: () => _addTask(
                        ctx,
                        listId,
                        titleController.text,
                        notesController.text.trim().isEmpty
                            ? null
                            : notesController.text.trim(),
                        dueDate,
                        reminder,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addTask(
    BuildContext ctx,
    int listId,
    String title,
    String? notes,
    DateTime? dueDate,
    DateTime? reminder,
  ) {
    if (title.trim().isEmpty) return;
    final notificationService = RepositoryScope.of(ctx).notificationService;
    _taskRepository
        .insertTask(
          listId,
          title.trim(),
          notes: notes,
          dueDate: dueDate,
          reminder: reminder,
        )
        .then((id) {
          if (reminder != null) {
            notificationService.scheduleReminder(id, title.trim(), reminder);
          }
        });
    if (ctx.mounted) Navigator.pop(ctx);
  }

  void _showEditTaskSheet(Task task) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TaskEditSheetContent(
        task: task,
        taskRepo: _taskRepository,
        notificationService: RepositoryScope.of(context).notificationService,
        formatDate: _formatDate,
        formatDateTime: _formatDateTime,
        formatDueDate: _formatDueDate,
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              RepositoryScope.of(
                context,
              ).notificationService.cancelReminder(task.id);
              _taskRepository.deleteTask(task.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  static const _drawerTileGap = 8.0;
  static const _drawerTileLead = 32.0;

  Widget _buildDrawer(BuildContext context) {
    void selectVirtual(String key) {
      setState(() {
        _selectedVirtualKey = key;
        _selectedListId = null;
      });
      _subscribeToTasks();
      Navigator.pop(context);
    }

    void selectList(int id) {
      setState(() {
        _selectedVirtualKey = null;
        _selectedListId = id;
      });
      _subscribeToTasks();
      Navigator.pop(context);
    }

    return Drawer(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Section 1: Inbox, Today, Tomorrow, Next 7 days, All
            Watch((context) {
              final inbox = _listsSignal.value
                  .where((l) => l.name == _inboxName)
                  .firstOrNull;
              if (inbox == null) return const SizedBox.shrink();
              return ListTile(
                leading: const Icon(Icons.inbox, size: 22),
                title: const Text('Inbox'),
                horizontalTitleGap: _drawerTileGap,
                minLeadingWidth: _drawerTileLead,
                selected:
                    _selectedVirtualKey == null && _selectedListId == inbox.id,
                onTap: () => selectList(inbox.id),
                onLongPress: null,
              );
            }),
            ListTile(
              leading: const Icon(Icons.today, size: 22),
              title: const Text('Today'),
              horizontalTitleGap: _drawerTileGap,
              minLeadingWidth: _drawerTileLead,
              selected: _selectedVirtualKey == _virtualToday,
              onTap: () => selectVirtual(_virtualToday),
            ),
            ListTile(
              leading: const Icon(Icons.event, size: 22),
              title: const Text('Tomorrow'),
              horizontalTitleGap: _drawerTileGap,
              minLeadingWidth: _drawerTileLead,
              selected: _selectedVirtualKey == _virtualTomorrow,
              onTap: () => selectVirtual(_virtualTomorrow),
            ),
            ListTile(
              leading: const Icon(Icons.date_range, size: 22),
              title: const Text('Next 7 days'),
              horizontalTitleGap: _drawerTileGap,
              minLeadingWidth: _drawerTileLead,
              selected: _selectedVirtualKey == _virtualNext7,
              onTap: () => selectVirtual(_virtualNext7),
            ),
            ListTile(
              leading: const Icon(Icons.view_list, size: 22),
              title: const Text('All'),
              horizontalTitleGap: _drawerTileGap,
              minLeadingWidth: _drawerTileLead,
              selected: _selectedVirtualKey == _virtualAll,
              onTap: () => selectVirtual(_virtualAll),
            ),
            const Divider(),
            // Section 2: Custom lists (divider only when there are custom lists)
            Watch((context) {
              final userLists = _listsSignal.value
                  .where((l) => l.name != _inboxName)
                  .toList();
              if (userLists.isEmpty) return const SizedBox.shrink();
              return Column(
                children: [
                  ...userLists.map(
                    (list) => ListTile(
                      leading: const Icon(Icons.list_alt, size: 22),
                      title: Text(list.name),
                      horizontalTitleGap: _drawerTileGap,
                      minLeadingWidth: _drawerTileLead,
                      selected:
                          _selectedVirtualKey == null &&
                          _selectedListId == list.id,
                      onTap: () => selectList(list.id),
                      onLongPress: () => _showListOptions(context, list),
                    ),
                  ),
                  const Divider(),
                ],
              );
            }),
            // Section 3: Completed, Trash
            ListTile(
              leading: const Icon(Icons.check_circle_outline, size: 22),
              title: const Text('Completed'),
              horizontalTitleGap: _drawerTileGap,
              minLeadingWidth: _drawerTileLead,
              selected: _selectedVirtualKey == _virtualCompleted,
              onTap: () => selectVirtual(_virtualCompleted),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, size: 22),
              title: const Text('Trash'),
              horizontalTitleGap: _drawerTileGap,
              minLeadingWidth: _drawerTileLead,
              selected: _selectedVirtualKey == _virtualTrash,
              onTap: () => selectVirtual(_virtualTrash),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add list'),
              horizontalTitleGap: 8,
              minLeadingWidth: 32,
              onTap: _showAddListDialog,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddListDialog() {
    final wasDrawerOpen = _scaffoldKey.currentState?.isDrawerOpen ?? false;
    if (wasDrawerOpen) {
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAddListSheet();
      });
      return;
    }
    _showAddListSheet();
  }

  void _showAddListSheet() {
    final controller = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            16 + MediaQuery.of(ctx).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'List name',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                  hintStyle: TextStyle(fontSize: 14),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addList(controller.text, ctx),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Spacer(),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(ctx).colorScheme.primary,
                    ),
                    icon: const Icon(Icons.check, color: Colors.white),
                    tooltip: 'Add list',
                    onPressed: () => _addList(controller.text, ctx),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addList(String name, BuildContext sheetContext) async {
    if (name.trim().isEmpty) return;
    final id = await _repo.insertList(name.trim());
    if (!mounted) return;
    final listName = name.trim();
    setState(() {
      _selectedVirtualKey = null;
      _selectedListId = id;
      _createdListId = id;
      _createdListName = listName;
    });
    _subscribeToTasks();
    if (sheetContext.mounted) Navigator.pop(sheetContext);
    if (!mounted) return;
    // Close drawer after sheet is dismissed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scaffoldKey.currentState?.closeDrawer();
    });
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => _renameList(list.id, controller.text, ctx),
            child: const Text('Save'),
          ),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              _repo.deleteList(list.id);
              if (_selectedListId == list.id) {
                setState(() {
                  _selectedVirtualKey = _virtualAll;
                  _selectedListId = null;
                });
                _subscribeToTasks();
              }
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
    required this.formatDateTime,
    required this.formatDueDate,
  });

  final Task task;
  final TaskRepository taskRepo;
  final NotificationService notificationService;
  final String Function(DateTime) formatDate;
  final String Function(DateTime) formatDateTime;
  final String Function(DateTime) formatDueDate;

  @override
  State<_TaskEditSheetContent> createState() => _TaskEditSheetContentState();
}

class _TaskEditSheetContentState extends State<_TaskEditSheetContent> {
  late final TextEditingController _titleController = TextEditingController(
    text: widget.task.title,
  );
  late final TextEditingController _notesController = TextEditingController(
    text: widget.task.notes ?? '',
  );
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

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _dueDate != null
          ? TimeOfDay.fromDateTime(_dueDate!)
          : TimeOfDay.fromDateTime(now),
    );
    if (time != null && mounted) {
      setState(
        () => _dueDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _reminder ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _reminder != null
          ? TimeOfDay.fromDateTime(_reminder!)
          : TimeOfDay.fromDateTime(now),
    );
    if (time != null && mounted) {
      setState(
        () => _reminder = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> _saveTask() async {
    final id = widget.task.id;
    final title = _titleController.text.trim();
    widget.notificationService.cancelReminder(id);
    await widget.taskRepo.updateTask(
      id,
      title: title,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      dueDate: _dueDate,
      reminder: _reminder,
    );
    if (_reminder != null) {
      widget.notificationService.scheduleReminder(id, title, _reminder!);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          16 + MediaQuery.of(context).padding.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: 'What would you like to do?',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                  hintStyle: TextStyle(fontSize: 14),
                ),
                textInputAction: TextInputAction.next,
              ),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  hintText: 'Description',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                maxLines: 2,
                minLines: 1,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _pickDueDate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _dueDate != null
                                ? Icons.calendar_today
                                : Icons.calendar_today_outlined,
                            size: 22,
                            color: _dueDate != null
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          if (_dueDate != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              widget.formatDueDate(_dueDate!),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _pickReminder,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _reminder != null
                                ? Icons.notifications
                                : Icons.notifications_outlined,
                            size: 22,
                            color: _reminder != null
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          if (_reminder != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              widget.formatDueDate(_reminder!),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                    ),
                    icon: const Icon(Icons.check, color: Colors.white),
                    tooltip: 'Save',
                    onPressed: _saveTask,
                  ),
                ],
              ),
              const Divider(height: 24),
              Text('Subtasks', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              ..._subtasks.map(
                (t) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t.title),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () async {
                      await widget.taskRepo.deleteTask(t.id);
                      _loadSubtasks();
                    },
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subtaskController,
                      decoration: const InputDecoration(
                        hintText: 'Add subtask',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      onSubmitted: (_) => _addSubtask(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addSubtask,
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
    widget.taskRepo.insertTask(
      widget.task.listId,
      title,
      parentId: widget.task.id,
    );
    _subtaskController.clear();
    _loadSubtasks();
  }
}
