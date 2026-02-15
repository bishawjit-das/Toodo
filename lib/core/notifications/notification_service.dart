import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'notification_background.dart';

class NotificationService {
  NotificationService() {
    _plugin = FlutterLocalNotificationsPlugin();
  }

  late final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  /// Called when user taps "Complete" on a reminder; receives taskId. Set before init().
  void Function(int taskId)? onCompleteTask;

  static const _completeActionId = 'complete';

  static AndroidNotificationDetails get _androidDetails =>
      AndroidNotificationDetails(
        'toodo_reminders',
        'Task reminders',
        channelDescription: 'Reminders for tasks',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            _completeActionId,
            'Complete',
            cancelNotification: true,
            showsUserInterface: false,
          ),
        ],
      );

  Future<void> init() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: android);
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      _initialized = true;
    } catch (_) {
      // Notifications not available (e.g. in tests or unsupported platform)
    }
  }

  void _onNotificationResponse(NotificationResponse? response) {
    _handleCompleteAction(response);
  }

  /// Foreground only: we have access to [onCompleteTask] and the main isolate.
  /// Background actions are handled by [notificationTapBackground] (separate isolate).
  void _handleCompleteAction(NotificationResponse? response) {
    if (response?.actionId != _completeActionId) return;
    final payload = response?.payload;
    if (payload == null || payload.isEmpty) return;
    final taskId = int.tryParse(payload);
    if (taskId == null) return;
    onCompleteTask?.call(taskId);
    cancelReminder(taskId);
  }

  /// Call after init() when app starts; handles launch from notification action (e.g. app was terminated).
  Future<void> handleLaunchFromNotification() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      _handleCompleteAction(details!.notificationResponse);
    }
  }

  /// Schedules a notification at [reminder] with [title]. Uses [taskId] as notification id for later cancel.
  Future<void> scheduleReminder(
    int taskId,
    String title,
    DateTime reminder,
  ) async {
    await init();
    if (!_initialized) return;
    try {
      final local = tz.TZDateTime.from(reminder, tz.local);
      if (local.isBefore(tz.TZDateTime.now(tz.local))) return;
      await _plugin.zonedSchedule(
        taskId,
        title,
        null,
        local,
        NotificationDetails(android: _androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: taskId.toString(),
      );
    } catch (_) {}
  }

  Future<void> cancelReminder(int taskId) async {
    try {
      await _plugin.cancel(taskId);
    } catch (_) {}
  }
}
