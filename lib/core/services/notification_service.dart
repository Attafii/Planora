import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  final plugin = FlutterLocalNotificationsPlugin();
  static Future<void> _pendingAlerts = Future.value();

  Future<void> _queue(Future<void> Function() operation) {
    final result = _pendingAlerts.then((_) => operation());
    _pendingAlerts = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  bool initialized = false;
  String message = 'Enable notifications to receive reminders outside the app.';
  String? openedReminder;
  VoidCallback? onOpen;
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  Future<void> init() async {
    if (!supported) {
      message = 'Native reminders are available in the Android and iOS app.';
      return;
    }
    data.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        openedReminder = r.payload;
        onOpen?.call();
      },
    );
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      openedReminder = launch?.notificationResponse?.payload;
    }
    initialized = true;
  }

  Future<void> request() async {
    if (!initialized) return;
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ios = plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final granted = android != null
        ? await android.requestNotificationsPermission()
        : await ios?.requestPermissions(alert: true, badge: true, sound: true);
    message = granted == true
        ? 'Notifications enabled. Battery settings may delay alerts.'
        : 'Notifications disabled. Allow them in your device settings.';
  }

  int id(String value) => int.parse(value).remainder(2000000000);
  static const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'planify_reminders',
      'Planify reminders',
      channelDescription: 'Focus and reminder alerts',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );
  Future<void> schedule(
    String key,
    String title,
    DateTime when,
    String repeat,
    bool enabled,
  ) => _queue(() async {
    if (!initialized) return;
    try {
      await plugin.cancel(id: id(key));
      if (!enabled || !when.isAfter(DateTime.now())) return;
      await plugin.zonedSchedule(
        id: id(key),
        title: 'Planify',
        body: title,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: repeat == 'Daily'
            ? DateTimeComponents.time
            : repeat == 'Weekly'
            ? DateTimeComponents.dayOfWeekAndTime
            : null,
        payload: key,
      );
    } catch (_) {
      message = 'Reminder saved, but its device alert could not be scheduled.';
    }
  });

  Future<void> cancel(String key) => _queue(() async {
    if (initialized) await plugin.cancel(id: id(key));
  });

  Future<void> clearDeviceAlerts() => _queue(() async {
    if (supported) await plugin.cancelAll();
  });

  Future<void> timer(DateTime when, String title) =>
      schedule('2000000001', title, when, 'Once', true);
  Future<void> cancelTimer() => cancel('2000000001');
}
