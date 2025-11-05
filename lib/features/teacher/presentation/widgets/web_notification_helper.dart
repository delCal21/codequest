// Only import this file on web!
import 'dart:html' as html;

void showPlatformNotification(String title, String body) {
  if (html.Notification.supported &&
      html.Notification.permission == 'granted') {
    html.Notification(title, body: body);
  }
}
