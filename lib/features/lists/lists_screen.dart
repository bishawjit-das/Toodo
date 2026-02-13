import 'dart:async';

import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:toodo/core/scope/repository_scope.dart';
import 'package:toodo/data/database/app_database.dart';
import 'package:toodo/data/repositories/list_repository.dart';

class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  ListRepository? _listRepo;
  late final Signal<List<ListRow>> _listsSignal = signal<List<ListRow>>([]);
  StreamSubscription<List<ListRow>>? _sub;
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
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  ListRepository get _repo => _listRepo!;

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
      body: Watch((context) => Center(child: Text(_selectedListId == null ? 'All tasks' : _titleFor(_selectedListId)))),
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
            onTap: () => setState(() => _selectedListId = null),
          ),
          Watch((context) {
            final lists = _listsSignal.value;
            return Column(
              children: lists
                  .map((list) => ListTile(
                        title: Text(list.name),
                        selected: _selectedListId == list.id,
                        onTap: () => setState(() => _selectedListId = list.id),
                        onLongPress: () => _showListOptions(context, list),
                      ))
                  .toList(),
            );
          }),
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
    Navigator.of(context).pop(); // close drawer if open
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
