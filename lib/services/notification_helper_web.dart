import 'dart:html' as html;

void showBrowserNotification(String title, String body) {
  try {
    if (html.Notification.permission == 'granted') {
      html.Notification(title, body: body);
    } else if (html.Notification.permission != 'denied') {
      html.Notification.requestPermission().then((permission) {
        if (permission == 'granted') {
          html.Notification(title, body: body);
        }
      });
    }
  } catch (e) {
    // Fail silently or print fallback logs
  }
}

String getBrowserNotificationPermission() {
  try {
    return html.Notification.permission ?? 'unknown';
  } catch (e) {
    return 'unknown';
  }
}

Future<String> requestBrowserNotificationPermission() async {
  try {
    final status = await html.Notification.requestPermission();
    return status;
  } catch (e) {
    return 'unsupported';
  }
}
