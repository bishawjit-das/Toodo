import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService() {
    _plugin = FlutterLocalNotificationsPlugin();
  }

  late final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const AndroidNotificationDetails _androidDetails = AndroidNotificationDetails(
    'toodo_reminders',
    'Task reminders',
    channelDescription: 'Reminders for tasks',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  Future<void> init() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
      try {
        final name = await FlutterNativeTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(name));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: android);
      await _plugin.initialize(initSettings);
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _initialized = true;
    } catch (_) {
      // Notifications not available (e.g. in tests or unsupported platform)
    }
  }

  /// Schedules a notification at [reminder] with [title]. Uses [taskId] as notification id for later cancel.
  Future<void> scheduleReminder(int taskId, String title, DateTime reminder) async {
    await init();
    if (!_initialized) return;
    try {
      final local = tz.TZDateTime.from(reminder, tz.local);
      if (local.isBefore(tz.TZDateTime.now(tz.local))) return;
      await _plugin.zonedSchedule(
      taskId,
      title,
      'Reminder',
      local,
      NotificationDetails(android: _androidDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
    } catch (_) {}
  }

  Future<void> cancelReminder(int taskId) async {
    try {
      await _plugin.cancel(taskId);
    } catch (_) {}
  }
}
