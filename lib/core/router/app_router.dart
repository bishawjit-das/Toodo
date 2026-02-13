import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

GoRouter createAppRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const _PlaceholderScreen(title: 'Home')),
        GoRoute(path: '/list/:id', builder: (_, state) => _PlaceholderScreen(title: 'List ${state.pathParameters['id']}')),
        GoRoute(path: '/task/:id', builder: (_, state) => _PlaceholderScreen(title: 'Task ${state.pathParameters['id']}')),
      ],
    );

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text(title)));
}
