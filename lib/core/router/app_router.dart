import 'package:go_router/go_router.dart';
import 'package:toodo/features/lists/lists_screen.dart';
import 'package:toodo/features/settings/settings_screen.dart';

GoRouter createAppRouter() => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const ListsScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
  ],
);
