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
  bool _tasksLoaded = false;

  /// Virtual view: 'all', 'today', 'tomorrow', 'next7'. When null, a list is selected.
  String? _selectedVirtualKey = _virtualAll;
  int? _selectedListId;
  bool _inboxEnsured = false;

  /// Name of list just created; used as title until watchLists() emits.
  int? _createdListId;
  String? _createdListName;
  bool _isDrawerOpen = false;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  Timer? _permissionTimer;
  bool _permissionRequestScheduled = false;

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
    if (!_permissionRequestScheduled) {
      _permissionRequestScheduled = true;
      _permissionTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) scope.notificationService.requestPermissions();
      });
    }
  }

  void _applyTaskFilter(List<Task> data) {
    if (_ignoreNextTaskEmission) {
      _ignoreNextTaskEmission = false;
      if (mounted) setState(() => _tasksLoaded = true);
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
    if (mounted) setState(() => _tasksLoaded = true);
  }

  void _subscribeToTasks() {
    _taskSub?.cancel();
    final repo = _taskRepo;
    if (repo == null) return;
    setState(() => _tasksLoaded = false);
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

  /// On resume: one-shot read then re-subscribe so UI sees latest data (e.g. after background complete).
  Future<void> _refreshTasksThenResubscribe() async {
    final repo = _taskRepo;
    if (repo == null) return;
    List<Task> data;
    if (_selectedVirtualKey == _virtualTrash) {
      data = await repo.getTrashTasks();
    } else if (_selectedVirtualKey != null) {
      data = await repo.getAllTasks();
    } else {
      final listId = _selectedListId;
      if (listId == null) return;
      data = await repo.getTasksByListId(listId);
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
    _permissionTimer?.cancel();
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
    final settings = RepositoryScope.of(context).settingsRepository;
    final leftAction = settings?.leftSwipeAction ?? SwipeAction.trash;
    final rightAction = settings?.rightSwipeAction ?? SwipeAction.edit;
    final isDrawerOpen =
        _scaffoldKey.currentState?.isDrawerOpen ?? _isDrawerOpen;
    return PopScope(
      canPop: !isDrawerOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _scaffoldKey.currentState?.closeDrawer();
        _isDrawerOpen = false;
        if (mounted) setState(() {});
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          titleSpacing: 0,
          leading: IconButton(
            key: const Key('drawer_menu'),
            icon: const Icon(Icons.menu),
            onPressed: () {
              _isDrawerOpen = true;
              _scaffoldKey.currentState?.openDrawer();
              if (mounted) setState(() {});
            },
          ),
          title: Watch(
            (context) => Text(
              _titleFor(),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 5.0),
              child: IconButton(
                key: const Key('settings'),
                icon: const Icon(Icons.settings),
                onPressed: () => context.push('/settings'),
              ),
            ),
          ],
        ),
        drawer: _buildDrawer(context),
        body: _buildTaskList(leftAction, rightAction),
        floatingActionButton: _buildFloatingActionButton(),
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    if (_selectedVirtualKey == _virtualCompleted) {
      final tasks = _tasksSignal.value;
      if (tasks.isEmpty) return null;
      return FloatingActionButton(
        onPressed: _trashAllCompleted,
        tooltip: 'Trash all completed',
        child: const Icon(Icons.delete_sweep),
      );
    }
    if (_selectedVirtualKey == _virtualTrash) {
      final tasks = _tasksSignal.value;
      if (tasks.isEmpty) return null;
      return FloatingActionButton(
        onPressed: _deleteAllTrash,
        tooltip: 'Delete all permanently',
        child: const Icon(Icons.delete_forever),
      );
    }
    if (_selectedVirtualKey != _virtualTrash &&
        (_selectedVirtualKey != null || _effectiveListId != null)) {
      return FloatingActionButton(
        onPressed: _showAddTaskSheet,
        child: const Icon(Icons.add),
      );
    }
    return null;
  }

  Future<void> _trashAllCompleted() async {
    final tasks = _tasksSignal.value;
    if (tasks.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trash all completed?'),
        content: Text(
          'Move ${tasks.length} completed task${tasks.length == 1 ? '' : 's'} to Trash.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Trash all'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final notificationService = RepositoryScope.of(context).notificationService;
    for (final task in tasks) {
      notificationService.cancelReminder(task.id);
      await _taskRepository.softDelete(task.id);
    }
    if (mounted) setState(() {});
  }

  Future<void> _deleteAllTrash() async {
    final tasks = _tasksSignal.value;
    if (tasks.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all permanently?'),
        content: const Text(
          'This cannot be undone. All tasks in Trash will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final notificationService = RepositoryScope.of(context).notificationService;
    for (final task in tasks) {
      notificationService.cancelReminder(task.id);
      await _taskRepository.deleteTask(task.id);
    }
    if (mounted) setState(() {});
  }

  Widget _buildTaskList(SwipeAction leftAction, SwipeAction rightAction) {
    return Watch((context) {
      final tasks = _tasksSignal.value;
      if (!_tasksLoaded) {
        return const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }
      if (tasks.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.checklist_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              SizedBox(height: 6),
              Text(
                'No tasks',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      }
      final isTrash = _selectedVirtualKey == _virtualTrash;
      return ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          final primary = Theme.of(context).colorScheme.primary;
          final subtitleChildren = <Widget>[
            if (task.notes != null && task.notes!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  task.notes!.trim().split(RegExp(r'[\r\n]+')).first,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (task.dueDate != null || task.reminder != null)
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (task.dueDate != null)
                    Text(
                      _formatDueDate(task.dueDate!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: primary,
                        fontSize: 13,
                      ),
                    ),
                  if (task.reminder != null)
                    Icon(Icons.alarm, size: 14, color: primary),
                ],
              ),
          ];
          final tile = ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 0,
            ),
            dense: false,
            horizontalTitleGap: 4,
            minLeadingWidth: 32,
            visualDensity: const VisualDensity(horizontal: -2, vertical: -4),
            leading: Checkbox(
              value: task.completedAt != null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              onChanged: isTrash ? null : (_) => _toggleTask(task),
            ),
            title: Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.2,
                  decoration: task.completedAt != null
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
            subtitle: subtitleChildren.isEmpty
                ? null
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: subtitleChildren,
                  ),
            onTap: () => _showEditTaskSheet(task),
          );
          if (isTrash) return tile;
          return Dismissible(
            key: ValueKey(task.id),
            direction: DismissDirection.horizontal,
            confirmDismiss: (direction) async {
              final action = direction == DismissDirection.endToStart
                  ? leftAction
                  : rightAction;
              if (action == SwipeAction.edit) {
                _showEditTaskSheet(task);
                return false;
              }
              if (action == SwipeAction.trash) {
                RepositoryScope.of(
                  context,
                ).notificationService.cancelReminder(task.id);
                _taskRepository.softDelete(task.id);
              } else {
                _taskRepository.completeTask(task.id);
              }
              return true;
            },
            background: _swipeBackground(
              context,
              rightAction,
              Alignment.centerLeft,
              EdgeInsets.only(left: 16),
            ),
            secondaryBackground: _swipeBackground(
              context,
              leftAction,
              Alignment.centerRight,
              EdgeInsets.only(right: 16),
            ),
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
    final ampm = (d.hour < 12 ? 'AM' : 'PM');
    final timeStr = hasTime
        ? ' $hour12:${d.minute.toString().padLeft(2, '0')}$ampm'
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddTaskSheetContent(
        listId: listId,
        taskRepo: _taskRepository,
        notificationService: RepositoryScope.of(context).notificationService,
        formatDueDate: _formatDueDate,
        onSave: (title, notes, dueDate, reminder, subtaskTitles) => _addTask(
          ctx,
          listId,
          title,
          notes,
          dueDate,
          reminder,
          subtaskTitles,
        ),
      ),
    );
  }

  Future<void> _addTask(
    BuildContext ctx,
    int listId,
    String title,
    String? notes,
    DateTime? dueDate,
    DateTime? reminder,
    List<String> subtaskTitles,
  ) async {
    if (title.trim().isEmpty) return;
    final notificationService = RepositoryScope.of(ctx).notificationService;
    final id = await _taskRepository.insertTask(
      listId,
      title.trim(),
      notes: notes,
      dueDate: dueDate,
      reminder: reminder,
    );
    for (final t in subtaskTitles) {
      if (t.trim().isEmpty) continue;
      await _taskRepository.insertTask(listId, t.trim(), parentId: id);
    }
    if (reminder != null) {
      notificationService.scheduleReminder(id, title.trim(), reminder);
    }
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
        formatDueDate: _formatDueDate,
      ),
    );
  }

  static const _drawerTileGap = 8.0;
  static const _drawerTileLead = 32.0;
  static const _drawerTitleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

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
      child: _DrawerCloseNotifier(
        onClose: () {
          _isDrawerOpen = false;
          Future<void>.delayed(Duration.zero, () {
            if (mounted) setState(() {});
          });
        },
        child: SafeArea(
          child: ListTileTheme(
            data: ListTileTheme.of(context).copyWith(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                // Section 1: All, Inbox, Today, Tomorrow, Next 7 days
                ListTile(
                  leading: const Icon(Icons.view_list, size: 22),
                  title: const Text('All', style: _drawerTitleStyle),
                  horizontalTitleGap: _drawerTileGap,
                  minLeadingWidth: _drawerTileLead,
                  selected: _selectedVirtualKey == _virtualAll,
                  onTap: () => selectVirtual(_virtualAll),
                ),
                Watch((context) {
                  final inbox = _listsSignal.value
                      .where((l) => l.name == _inboxName)
                      .firstOrNull;
                  if (inbox == null) return const SizedBox.shrink();
                  return ListTile(
                    leading: const Icon(Icons.inbox, size: 22),
                    title: const Text('Inbox', style: _drawerTitleStyle),
                    horizontalTitleGap: _drawerTileGap,
                    minLeadingWidth: _drawerTileLead,
                    selected:
                        _selectedVirtualKey == null &&
                        _selectedListId == inbox.id,
                    onTap: () => selectList(inbox.id),
                    onLongPress: null,
                  );
                }),
                ListTile(
                  leading: const Icon(Icons.today, size: 22),
                  title: const Text('Today', style: _drawerTitleStyle),
                  horizontalTitleGap: _drawerTileGap,
                  minLeadingWidth: _drawerTileLead,
                  selected: _selectedVirtualKey == _virtualToday,
                  onTap: () => selectVirtual(_virtualToday),
                ),
                ListTile(
                  leading: const Icon(Icons.event, size: 22),
                  title: const Text('Tomorrow', style: _drawerTitleStyle),
                  horizontalTitleGap: _drawerTileGap,
                  minLeadingWidth: _drawerTileLead,
                  selected: _selectedVirtualKey == _virtualTomorrow,
                  onTap: () => selectVirtual(_virtualTomorrow),
                ),
                ListTile(
                  leading: const Icon(Icons.date_range, size: 22),
                  title: const Text('Next 7 days', style: _drawerTitleStyle),
                  horizontalTitleGap: _drawerTileGap,
                  minLeadingWidth: _drawerTileLead,
                  selected: _selectedVirtualKey == _virtualNext7,
                  onTap: () => selectVirtual(_virtualNext7),
                ),
                const Divider(),
                // Section 2: Custom lists
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
                          title: Text(list.name, style: _drawerTitleStyle),
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
                // Section 3: Completed, Trash, Add list
                ListTile(
                  leading: const Icon(Icons.check_circle_outline, size: 22),
                  title: const Text('Completed', style: _drawerTitleStyle),
                  horizontalTitleGap: _drawerTileGap,
                  minLeadingWidth: _drawerTileLead,
                  selected: _selectedVirtualKey == _virtualCompleted,
                  onTap: () => selectVirtual(_virtualCompleted),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, size: 22),
                  title: const Text('Trash', style: _drawerTitleStyle),
                  horizontalTitleGap: _drawerTileGap,
                  minLeadingWidth: _drawerTileLead,
                  selected: _selectedVirtualKey == _virtualTrash,
                  onTap: () => selectVirtual(_virtualTrash),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Add list', style: _drawerTitleStyle),
                  horizontalTitleGap: 8,
                  minLeadingWidth: 32,
                  onTap: _showAddListDialog,
                ),
              ],
            ),
          ),
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
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
                textCapitalization: TextCapitalization.sentences,
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

/// Wraps drawer content; [onClose] is called when the drawer is disposed (e.g. tap outside).
class _DrawerCloseNotifier extends StatefulWidget {
  const _DrawerCloseNotifier({required this.onClose, required this.child});
  final VoidCallback onClose;
  final Widget child;

  @override
  State<_DrawerCloseNotifier> createState() => _DrawerCloseNotifierState();
}

class _DrawerCloseNotifierState extends State<_DrawerCloseNotifier> {
  @override
  void dispose() {
    widget.onClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

typedef _DateReminderResult = (DateTime?, DateTime?);

/// Returns (dueDate, reminder) on confirm, null on cancel. Default due = today, reminder = today 09:00.
Future<_DateReminderResult?> _showDateTimeReminderSheet(
  BuildContext context, {
  DateTime? initialDueDate,
  DateTime? initialReminder,
}) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final due = initialDueDate ?? today;
  final rem = initialReminder ?? DateTime(now.year, now.month, now.day, 9, 0);
  return showModalBottomSheet<_DateReminderResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _DateTimeReminderSheetContent(
      initialDueDate: due,
      initialReminder: rem,
    ),
  );
}

class _DateTimeReminderSheetContent extends StatefulWidget {
  const _DateTimeReminderSheetContent({
    required this.initialDueDate,
    required this.initialReminder,
  });

  final DateTime initialDueDate;
  final DateTime initialReminder;

  @override
  State<_DateTimeReminderSheetContent> createState() =>
      _DateTimeReminderSheetContentState();
}

class _DateTimeReminderSheetContentState
    extends State<_DateTimeReminderSheetContent> {
  late DateTime _selectedDate;
  TimeOfDay? _dueTime;
  TimeOfDay? _reminderTime;
  int _quickChipTapCount = 0;

  static const _defaultReminder = TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.initialDueDate.year,
      widget.initialDueDate.month,
      widget.initialDueDate.day,
    );
    _dueTime =
        widget.initialDueDate.hour != 0 || widget.initialDueDate.minute != 0
        ? TimeOfDay.fromDateTime(widget.initialDueDate)
        : null;
    _reminderTime =
        widget.initialReminder.hour != 0 || widget.initialReminder.minute != 0
        ? TimeOfDay.fromDateTime(widget.initialReminder)
        : _defaultReminder;
  }

  void _confirm() {
    final due = _dueTime == null
        ? DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)
        : DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            _dueTime!.hour,
            _dueTime!.minute,
          );
    final reminder = _reminderTime == null
        ? null
        : DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            _reminderTime!.hour,
            _reminderTime!.minute,
          );
    Navigator.pop(context, (due, reminder));
  }

  void _selectQuick(DateTime date, {TimeOfDay? time}) {
    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day);
      if (time != null) _dueTime = time;
      _quickChipTapCount++;
    });
  }

  static DateTime _nextMonday(DateTime from) {
    var d = DateTime(from.year, from.month, from.day);
    while (d.weekday != DateTime.monday) {
      d = d.add(const Duration(days: 1));
    }
    if (d.isBefore(from) || d.isAtSameMomentAs(from)) {
      d = d.add(const Duration(days: 7));
    }
    return d;
  }

  DateTime get _now => DateTime.now();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final now = _now;
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              _buildHeader(theme, primary),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildQuickChips(theme, primary, today, tomorrow),
                      _buildCalendar(theme, primary),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTimeRow(theme),
                            _buildReminderRow(theme, primary),
                            _buildRepeatRow(theme),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Color primary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: primary, width: 2),
                    ),
                  ),
                  child: Text(
                    'Date',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Text(
                  'Duration',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.check, color: primary),
            onPressed: _confirm,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChips(
    ThemeData theme,
    Color primary,
    DateTime today,
    DateTime tomorrow,
  ) {
    final now = _now;
    final isToday =
        _selectedDate.year == today.year &&
        _selectedDate.month == today.month &&
        _selectedDate.day == today.day;
    final isTomorrow =
        _selectedDate.year == tomorrow.year &&
        _selectedDate.month == tomorrow.month &&
        _selectedDate.day == tomorrow.day;
    final nextMon = _nextMonday(now);
    final isNextMonday =
        _selectedDate.year == nextMon.year &&
        _selectedDate.month == nextMon.month &&
        _selectedDate.day == nextMon.day;
    final isTomorrowMorning =
        _selectedDate.year == tomorrow.year &&
        _selectedDate.month == tomorrow.month &&
        _selectedDate.day == tomorrow.day &&
        _dueTime?.hour == 9 &&
        _dueTime?.minute == 0;

    return Row(
      children: [
        _quickChip(
          theme,
          primary,
          label: 'Today',
          icon: Icons.calendar_today,
          selected: isToday,
          onTap: () => _selectQuick(today),
        ),
        const SizedBox(width: 8),
        _quickChip(
          theme,
          primary,
          label: 'Tomorrow',
          icon: Icons.wb_sunny_outlined,
          selected: isTomorrow && !isTomorrowMorning,
          onTap: () => _selectQuick(tomorrow),
        ),
        const SizedBox(width: 8),
        _quickChip(
          theme,
          primary,
          label: 'Next Monday',
          icon: Icons.calendar_today,
          selected: isNextMonday,
          onTap: () => _selectQuick(nextMon),
        ),
        const SizedBox(width: 8),
        _quickChip(
          theme,
          primary,
          label: 'Tomorrow Morning',
          icon: Icons.wb_sunny_outlined,
          selected: isTomorrowMorning,
          onTap: () => _selectQuick(tomorrow, time: _defaultReminder),
        ),
      ],
    );
  }

  Widget _quickChip(
    ThemeData theme,
    Color primary, {
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: selected
                      ? primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected
                        ? primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar(ThemeData theme, Color primary) {
    // Key forces rebuild so quick chips always navigate calendar to the chip's month (even if date unchanged).
    return CalendarDatePicker(
      key: ValueKey(
        '${_selectedDate.year}-${_selectedDate.month}-$_quickChipTapCount',
      ),
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      currentDate: DateTime.now(),
      onDateChanged: (d) => setState(() => _selectedDate = d),
    );
  }

  Widget _buildTimeRow(ThemeData theme) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      horizontalTitleGap: 0,
      leading: Icon(
        Icons.schedule,
        size: 22,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text('Time', style: theme.textTheme.bodyLarge),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_dueTime != null) ...[
            InkWell(
              onTap: () => setState(() => _dueTime = null),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(_dueTime!),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Icon(Icons.close, size: 20),
                ],
              ),
            ),
          ] else ...[
            InkWell(
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: _dueTime ?? _nextThirtyMinMark(DateTime.now()),
                );
                if (t != null && mounted) {
                  setState(() {
                    _dueTime = t;
                    _reminderTime = t;
                  });
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'None',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReminderRow(ThemeData theme, Color primary) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      horizontalTitleGap: 0,
      leading: Icon(
        Icons.alarm,
        size: 22,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text('Reminder', style: theme.textTheme.bodyLarge),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_reminderTime != null) ...[
            InkWell(
              onTap: () => setState(() => _reminderTime = null),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _reminderTime == _dueTime
                        ? 'On time'
                        : 'On the day (${_formatTime(_reminderTime!)})',
                    style: theme.textTheme.bodyMedium?.copyWith(color: primary),
                  ),
                  Icon(
                    Icons.close,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ] else ...[
            InkWell(
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: _reminderTime ?? _defaultReminder,
                );
                if (t != null && mounted) setState(() => _reminderTime = t);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'None',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRepeatRow(ThemeData theme) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      horizontalTitleGap: 0,
      leading: Icon(
        Icons.repeat,
        size: 22,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text('Repeat', style: theme.textTheme.bodyLarge),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'None',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
    );
  }

  /// Next :00 or :30 mark from [from]. E.g. 10:33 → 11:00, 11:01 → 11:30.
  static TimeOfDay _nextThirtyMinMark(DateTime from) {
    final minute = from.minute;
    if (minute < 30) return TimeOfDay(hour: from.hour, minute: 30);
    return TimeOfDay(hour: (from.hour + 1) % 24, minute: 0);
  }

  static String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute$period';
  }
}

class _AddTaskSheetContent extends StatefulWidget {
  const _AddTaskSheetContent({
    required this.listId,
    required this.taskRepo,
    required this.notificationService,
    required this.formatDueDate,
    required this.onSave,
  });

  final int listId;
  final TaskRepository taskRepo;
  final NotificationService notificationService;
  final String Function(DateTime) formatDueDate;
  final Future<void> Function(
    String title,
    String? notes,
    DateTime? dueDate,
    DateTime? reminder,
    List<String> subtaskTitles,
  )
  onSave;

  @override
  State<_AddTaskSheetContent> createState() => _AddTaskSheetContentState();
}

class _AddTaskSheetContentState extends State<_AddTaskSheetContent> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _subtaskController = TextEditingController();
  DateTime? _dueDate;
  DateTime? _reminder;
  final List<String> _subtaskTitles = [];

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  Future<void> _pickDateAndReminder() async {
    final result = await _showDateTimeReminderSheet(
      context,
      initialDueDate: _dueDate,
      initialReminder: _reminder,
    );
    if (result != null && mounted) {
      setState(() {
        _dueDate = result.$1;
        _reminder = result.$2;
      });
    }
  }

  Future<void> _submit() => widget.onSave(
    _titleController.text,
    _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    _dueDate,
    _reminder,
    List.from(_subtaskTitles),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
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
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'What would you like to do?',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                  hintStyle: TextStyle(fontSize: 16),
                ),
                style: TextStyle(fontSize: 16),
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  hintText: 'Description',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                minLines: 1,
                textInputAction: TextInputAction.done,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _pickDateAndReminder,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _dueDate != null || _reminder != null
                                ? Icons.calendar_month
                                : Icons.calendar_month_outlined,
                            size: 22,
                            color: _dueDate != null || _reminder != null
                                ? primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          if (_dueDate != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              widget.formatDueDate(_dueDate!),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: primary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          if (_reminder != null && _dueDate == null) ...[
                            const SizedBox(width: 6),
                            Text(
                              widget.formatDueDate(_reminder!),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: primary),
                    icon: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 22,
                    ),
                    tooltip: 'Add task',
                    onPressed: () => _submit(),
                  ),
                ],
              ),
              //   const Divider(height: 24),
              //   Text('Subtasks', style: theme.textTheme.titleSmall),
              //   const SizedBox(height: 4),
              //   ..._subtaskTitles.asMap().entries.map(
              //     (e) => ListTile(
              //       contentPadding: EdgeInsets.zero,
              //       title: Text(e.value),
              //       trailing: IconButton(
              //         icon: const Icon(Icons.close, size: 20),
              //         onPressed: () =>
              //             setState(() => _subtaskTitles.removeAt(e.key)),
              //       ),
              //     ),
              //   ),
              //   Row(
              //     children: [
              //       Expanded(
              //         child: TextField(
              //           controller: _subtaskController,
              //           decoration: const InputDecoration(
              //             hintText: 'Add subtask',
              //             border: InputBorder.none,
              //             contentPadding: EdgeInsets.zero,
              //             isDense: true,
              //           ),
              //           textCapitalization: TextCapitalization.sentences,
              //           onSubmitted: (_) => _addSubtask(),
              //         ),
              //       ),
              //       IconButton(
              //         icon: const Icon(Icons.add),
              //         onPressed: _addSubtask,
              //       ),
              //     ],
              //   ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskEditSheetContent extends StatefulWidget {
  const _TaskEditSheetContent({
    required this.task,
    required this.taskRepo,
    required this.notificationService,
    required this.formatDueDate,
  });

  final Task task;
  final TaskRepository taskRepo;
  final NotificationService notificationService;
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
  final Map<int, TextEditingController> _subtaskControllers = {};
  final Map<int, FocusNode> _subtaskFocusNodes = {};
  int? _focusedSubtaskId;
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
    if (!mounted) return;
    final newIds = list.map((t) => t.id).toSet();
    for (final t in list) {
      _subtaskControllers[t.id] ??= TextEditingController(text: t.title);
      _subtaskFocusNodes[t.id] ??= FocusNode()
        ..addListener(() {
          if (!mounted) return;
          final node = _subtaskFocusNodes[t.id]!;
          setState(() {
            if (node.hasFocus) {
              _focusedSubtaskId = t.id;
            } else if (_focusedSubtaskId == t.id) {
              _focusedSubtaskId = null;
            }
          });
        });
    }
    for (final id in _subtaskControllers.keys.toList()) {
      if (!newIds.contains(id)) {
        _subtaskControllers[id]?.dispose();
        _subtaskControllers.remove(id);
      }
    }
    for (final id in _subtaskFocusNodes.keys.toList()) {
      if (!newIds.contains(id)) {
        _subtaskFocusNodes[id]?.dispose();
        _subtaskFocusNodes.remove(id);
        if (_focusedSubtaskId == id) _focusedSubtaskId = null;
      }
    }
    setState(() => _subtasks = list);
  }

  @override
  void dispose() {
    for (final c in _subtaskControllers.values) {
      c.dispose();
    }
    _subtaskControllers.clear();
    for (final n in _subtaskFocusNodes.values) {
      n.dispose();
    }
    _subtaskFocusNodes.clear();
    _titleController.dispose();
    _notesController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  void _toggleSubtask(Task t) {
    if (t.completedAt != null) {
      widget.taskRepo.incompleteTask(t.id);
    } else {
      widget.taskRepo.completeTask(t.id);
    }
    _loadSubtasks();
  }

  Future<void> _saveSubtaskTitle(int id, String title) async {
    final t = title.trim();
    if (t.isEmpty) return;
    await widget.taskRepo.updateTask(id, title: t);
    _loadSubtasks();
  }

  Future<void> _pickDateAndReminder() async {
    final result = await _showDateTimeReminderSheet(
      context,
      initialDueDate: _dueDate,
      initialReminder: _reminder,
    );
    if (result != null && mounted) {
      setState(() {
        _dueDate = result.$1;
        _reminder = result.$2;
      });
    }
  }

  Future<void> _saveTask({String? capturedTitle, String? capturedNotes}) async {
    final id = widget.task.id;
    final title = capturedTitle ?? _titleController.text.trim();
    final notes = capturedNotes ?? _notesController.text.trim();
    widget.notificationService.cancelReminder(id);
    await widget.taskRepo.updateTask(
      id,
      title: title,
      notes: notes,
      dueDate: _dueDate,
      reminder: _reminder,
      clearReminder: _reminder == null,
    );
    if (_reminder != null) {
      widget.notificationService.scheduleReminder(id, title, _reminder!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final title = _titleController.text.trim();
          final notes = _notesController.text.trim();
          await _saveTask(capturedTitle: title, capturedNotes: notes);
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Padding(
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
                    hintStyle: TextStyle(fontSize: 16),
                  ),
                  textInputAction: TextInputAction.next,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    hintText: 'Description',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  maxLines: 2,
                  minLines: 1,
                  textInputAction: TextInputAction.done,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _pickDateAndReminder,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _dueDate != null || _reminder != null
                                  ? Icons.calendar_month
                                  : Icons.calendar_month_outlined,
                              size: 22,
                              color: _dueDate != null || _reminder != null
                                  ? primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            if (_dueDate != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                widget.formatDueDate(_dueDate!),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: primary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            if (_reminder != null && _dueDate == null) ...[
                              const SizedBox(width: 6),
                              Text(
                                widget.formatDueDate(_reminder!),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: primary,
                                ),
                              ),
                            ],
                            if (_reminder != null) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.alarm, size: 14, color: primary),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._subtasks.map((t) {
                  final controller = _subtaskControllers[t.id];
                  final isCompleted = t.completedAt != null;
                  if (controller == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: isCompleted,
                            splashRadius: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            onChanged: (_) => _toggleSubtask(t),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: controller,
                            focusNode: _subtaskFocusNodes[t.id],
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                              color: isCompleted
                                  ? theme.colorScheme.onSurfaceVariant
                                  : theme.colorScheme.onSurface,
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor:
                                  theme.colorScheme.onSurfaceVariant,
                            ),
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 0,
                                vertical: 2,
                              ),
                              isDense: true,
                            ),
                            onSubmitted: (v) => _saveSubtaskTitle(t.id, v),
                          ),
                        ),
                        if (_focusedSubtaskId == t.id)
                          InkWell(
                            onTap: () async {
                              await widget.taskRepo.deleteTask(t.id);
                              _loadSubtasks();
                            },
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: theme.colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
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
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                        onSubmitted: (_) => _addSubtask(),
                      ),
                    ),
                    InkWell(onTap: _addSubtask, child: Icon(Icons.add)),
                  ],
                ),
              ],
            ),
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
