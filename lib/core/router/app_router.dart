import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:toodo/features/calendar/calendar_screen.dart';
import 'package:toodo/features/lists/lists_screen.dart';
import 'package:toodo/features/settings/settings_screen.dart';

GoRouter createAppRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const ListsScreen()),
        GoRoute(path: '/calendar', builder: (context, state) => const CalendarScreen()),
        GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
        GoRoute(
          path: '/list/:id',
          builder: (context, state) => Scaffold(
            appBar: AppBar(title: Text('List ${state.pathParameters['id']}')),
            body: const Center(child: Text('List content')),
          ),
        ),
        GoRoute(
          path: '/task/:id',
          builder: (context, state) => Scaffold(
            appBar: AppBar(title: Text('Task ${state.pathParameters['id']}')),
            body: const Center(child: Text('Task content')),
          ),
        ),
      ],
    );
