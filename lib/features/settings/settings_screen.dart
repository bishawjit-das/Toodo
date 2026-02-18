import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:toodo/core/scope/repository_scope.dart';
import 'package:toodo/core/settings/settings_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late ThemeMode _themeMode;
  late SwipeAction _leftSwipeAction;
  late SwipeAction _rightSwipeAction;
  late Color _accentColor;
  static const _settingsTitleStyle = TextStyle(fontSize: 16);
  static const _settingsSubtitleStyle = TextStyle(fontSize: 14);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = RepositoryScope.of(context);
    final settings = scope.settingsRepository;
    if (settings != null) {
      _themeMode = settings.themeMode;
      _leftSwipeAction = settings.leftSwipeAction;
      _rightSwipeAction = settings.rightSwipeAction;
      _accentColor = settings.accentColor;
    } else {
      _themeMode = ThemeMode.system;
      _leftSwipeAction = SwipeAction.trash;
      _rightSwipeAction = SwipeAction.edit;
      _accentColor = predefinedAccentColors.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = RepositoryScope.of(context).settingsRepository;
    if (settings == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          titleSpacing: 0,
          title: const Text('Settings'),
        ),
        body: const Center(child: Text('Settings not available')),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, _) => context.pop(),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          titleSpacing: 0,
          title: const Text('Settings'),
        ),
        body: ListView(
          children: [
            ListTile(
              title: const Text('Theme', style: _settingsTitleStyle),
              subtitle: Text(
                _themeMode.name[0].toUpperCase() + _themeMode.name.substring(1),
                style: _settingsSubtitleStyle,
              ),
              onTap: () => _showThemePicker(context),
            ),
            ListTile(
              title: const Text('Left swipe', style: _settingsTitleStyle),
              subtitle: Text(
                _labelForSwipeAction(_leftSwipeAction),
                style: _settingsSubtitleStyle,
              ),
              onTap: () => _showSwipeActionPicker(context, isLeft: true),
            ),
            ListTile(
              title: const Text('Right swipe', style: _settingsTitleStyle),
              subtitle: Text(
                _labelForSwipeAction(_rightSwipeAction),
                style: _settingsSubtitleStyle,
              ),
              onTap: () => _showSwipeActionPicker(context, isLeft: false),
            ),
            ListTile(
              title: const Text('Accent color', style: _settingsTitleStyle),
              subtitle: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _accentColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Tap to change', style: _settingsSubtitleStyle),
                ],
              ),
              onTap: () => _showAccentColorPicker(context),
            ),
          ],
        ),
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
              .map(
                (mode) => ListTile(
                  title: Text(
                    mode.name[0].toUpperCase() + mode.name.substring(1),
                    style: _settingsTitleStyle,
                  ),
                  onTap: () async {
                    final scope = RepositoryScope.of(context);
                    await scope.settingsRepository?.setThemeMode(mode);
                    if (ctx.mounted) Navigator.pop(ctx);
                    setState(() => _themeMode = mode);
                    scope.themeModeNotifier?.value = mode;
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  String _labelForSwipeAction(SwipeAction a) {
    return switch (a) {
      SwipeAction.trash => 'Trash',
      SwipeAction.done => 'Done',
      SwipeAction.edit => 'Edit',
    };
  }

  void _showSwipeActionPicker(BuildContext context, {required bool isLeft}) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: SwipeAction.values
              .map(
                (action) => ListTile(
                  title: Text(
                    _labelForSwipeAction(action),
                    style: _settingsTitleStyle,
                  ),
                  onTap: () async {
                    final scope = RepositoryScope.of(context);
                    if (isLeft) {
                      await scope.settingsRepository?.setLeftSwipeAction(
                        action,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      setState(() => _leftSwipeAction = action);
                    } else {
                      await scope.settingsRepository?.setRightSwipeAction(
                        action,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      setState(() => _rightSwipeAction = action);
                    }
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _showAccentColorPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Predefined',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ...predefinedAccentColors.map(
                    (c) => GestureDetector(
                      onTap: () async {
                        final scope = RepositoryScope.of(context);
                        await scope.settingsRepository?.setAccentColor(c);
                        scope.accentColorNotifier?.value = c;
                        if (ctx.mounted) Navigator.pop(ctx);
                        setState(() => _accentColor = c);
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _accentColor.toARGB32() == c.toARGB32()
                                ? Theme.of(ctx).colorScheme.primary
                                : Colors.grey,
                            width: _accentColor.toARGB32() == c.toARGB32()
                                ? 3
                                : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Custom (hex)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showHexColorDialog(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHexColorDialog(BuildContext context) {
    final controller = TextEditingController(
      text:
          '#${_accentColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom accent color'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '#RRGGBB',
            labelText: 'Hex color',
          ),
          autofocus: true,
          onSubmitted: (_) => _applyHexColor(context, ctx, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => _applyHexColor(context, ctx, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _applyHexColor(
    BuildContext context,
    BuildContext dialogContext,
    String hex,
  ) {
    final s = hex.trim().replaceFirst(RegExp(r'^#'), '');
    if (s.length != 6) return;
    final r = int.tryParse(s.substring(0, 2), radix: 16);
    final g = int.tryParse(s.substring(2, 4), radix: 16);
    final b = int.tryParse(s.substring(4, 6), radix: 16);
    if (r == null || g == null || b == null) return;
    final color = Color.fromRGBO(r, g, b, 1);
    RepositoryScope.of(context).settingsRepository?.setAccentColor(color);
    RepositoryScope.of(context).accentColorNotifier?.value = color;
    setState(() => _accentColor = color);
    Navigator.pop(dialogContext);
  }
}
