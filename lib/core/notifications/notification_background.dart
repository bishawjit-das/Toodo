import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:toodo/data/database/app_database.dart';
import 'package:toodo/data/repositories/task_repository.dart';

/// Action id for "Complete"; must match NotificationService.
const String _completeActionId = 'complete';

/// Top-level background handler. Runs in a separate Dart isolate when the user
/// taps "Complete" while the app is in background or terminated. We cannot call
/// NotificationService.onCompleteTask here (different isolate); we must update
/// the database directly. UI stays in sync because the app uses Drift watch
/// streams on the same SQLite file—when the user reopens the app, streams
/// emit the updated state.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  if (notificationResponse.actionId != _completeActionId) return;
  final taskId = int.tryParse(notificationResponse.payload ?? '');
  if (taskId == null) return;
  await _completeTaskAndDismiss(taskId);
}

/// 1. Update database directly (persistence in background isolate).
/// 2. Dismiss the notification (required on some Android versions).
Future<void> _completeTaskAndDismiss(int taskId) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    final file = await AppDatabase.databaseFile;
    final executor = NativeDatabase.createInBackground(file);
    final db = AppDatabase(executor);
    final repo = TaskRepository(db);
    await repo.completeTask(taskId);
    await db.close();
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.cancel(taskId);
  } catch (_) {}
}
