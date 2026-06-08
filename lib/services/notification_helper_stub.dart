void showBrowserNotification(String title, String body) {
  // Stub - does nothing on non-web platforms (Windows, macOS, Linux, Android, iOS)
}

String getBrowserNotificationPermission() {
  return 'unsupported';
}

Future<String> requestBrowserNotificationPermission() async {
  return 'unsupported';
}
