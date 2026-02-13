import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:toodo/core/scope/repository_scope.dart';
import 'package:toodo/data/database/app_database.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late ThemeMode _themeMode;
  int? _defaultListId;
  StreamSubscription<List<ListRow>>? _sub;
  final _listsSignal = signal<List<ListRow>>([]);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = RepositoryScope.of(context);
    final settings = scope.settingsRepository;
    if (settings != null) {
      _themeMode = settings.themeMode;
      _defaultListId = settings.defaultListId;
    }
    _sub?.cancel();
    _sub = scope.listRepository.watchLists().listen((data) {
      _listsSignal.value = data;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = RepositoryScope.of(context).settingsRepository;
    if (settings == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/')),
          title: const Text('Settings'),
        ),
        body: const Center(child: Text('Settings not available')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Theme'),
            subtitle: Text(_themeMode.name),
            onTap: () => _showThemePicker(context),
          ),
          Watch((context) {
            final lists = _listsSignal.value;
            final defaultName = _defaultListId == null
                ? 'None'
                : lists.where((l) => l.id == _defaultListId).firstOrNull?.name ?? 'Unknown';
            return ListTile(
              title: const Text('Default list'),
              subtitle: Text(defaultName),
              onTap: () => _showDefaultListPicker(context, lists),
            );
          }),
        ],
      ),
    );
  }

  void _showThemePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values
              .map((mode) => ListTile(
                    title: Text(mode.name),
                    onTap: () async {
                      final scope = RepositoryScope.of(context);
                      await scope.settingsRepository?.setThemeMode(mode);
                      if (ctx.mounted) Navigator.pop(ctx);
                      setState(() => _themeMode = mode);
                      scope.themeModeNotifier?.value = mode;
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _showDefaultListPicker(BuildContext context, List<ListRow> lists) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('None'),
              onTap: () async {
                await RepositoryScope.of(context).settingsRepository?.setDefaultListId(null);
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() => _defaultListId = null);
              },
            ),
            ...lists.map((l) => ListTile(
                  title: Text(l.name),
                  onTap: () async {
                    await RepositoryScope.of(context).settingsRepository?.setDefaultListId(l.id);
                    if (ctx.mounted) Navigator.pop(ctx);
                    setState(() => _defaultListId = l.id);
                  },
                )),
          ],
        ),
      ),
    );
  }
}
