import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void showPlatformNotification(String title, String body) {
  flutterLocalNotificationsPlugin.show(
    0,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails('channel_id', 'channel_name',
          importance: Importance.max, priority: Priority.high),
      iOS: DarwinNotificationDetails(),
    ),
  );
}
