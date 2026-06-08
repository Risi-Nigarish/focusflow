import 'notification_helper_stub.dart'
    if (dart.library.html) 'notification_helper_web.dart' as helper;

void triggerBrowserNotification(String title, String body) {
  helper.showBrowserNotification(title, body);
}

String checkBrowserNotificationPermission() {
  return helper.getBrowserNotificationPermission();
}

Future<String> askBrowserNotificationPermission() {
  return helper.requestBrowserNotificationPermission();
}
