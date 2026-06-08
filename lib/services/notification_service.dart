import 'dart:async';
import 'dart:developer' as developer;
import '../models/task.dart';
import 'notification_helper.dart';

class NotificationPayload {
  final String taskId;
  final String taskTitle;
  final String message;
  final DateTime triggerTime;

  NotificationPayload({
    required this.taskId,
    required this.taskTitle,
    required this.message,
    required this.triggerTime,
  });
}

class NotificationService {
  // Singleton instance
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Timer? _timer;
  final _notificationStreamController = StreamController<NotificationPayload>.broadcast();
  
  // Keep track of tasks we are monitoring for reminders
  List<Task> _monitoredTasks = [];
  
  // Set to store already triggered reminder IDs (combination of taskId and ISO timestamp)
  // to prevent duplicate triggers during runtime
  final Set<String> _triggeredReminders = {};

  Stream<NotificationPayload> get notificationsStream => _notificationStreamController.stream;

  void initialize() {
    // Start checking for reminders every 5 seconds
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _checkReminders());
    developer.log('Notification Service Initialized');
  }

  void updateMonitoredTasks(List<Task> tasks) {
    // Only monitor uncompleted tasks that have reminders set in the future or very recently
    _monitoredTasks = tasks.where((task) => !task.isCompleted && task.reminders.isNotEmpty).toList();
    developer.log('Monitoring ${cleanMonitoredCount()} task reminders');
  }

  int cleanMonitoredCount() {
    int count = 0;
    for (var task in _monitoredTasks) {
      count += task.reminders.length;
    }
    return count;
  }

  void _checkReminders() {
    final now = DateTime.now();
    
    for (var task in _monitoredTasks) {
      for (var reminder in task.reminders) {
        final String reminderId = '${task.id}_${reminder.toIso8601String()}';
        
        // If the reminder time is in the past (up to 2 minutes ago to prevent stale alerts) 
        // and hasn't been triggered yet in this session
        if (reminder.isBefore(now) && 
            reminder.isAfter(now.subtract(const Duration(minutes: 2))) &&
            !_triggeredReminders.contains(reminderId)) {
          
          _triggeredReminders.add(reminderId);
          
          final payload = NotificationPayload(
            taskId: task.id,
            taskTitle: task.title,
            message: 'Reminder: "${task.title}" is due now! (${task.category})',
            triggerTime: reminder,
          );
          
          // Emit the notification to the visual overlay stream
          _notificationStreamController.add(payload);
          
          // Also try to show a web browser notification if running on web
          _showNativeWebNotification(payload);
        }
      }
    }
  }

  // Attempt to trigger native web notifications using browser JS Context if running on Chrome/Edge
  void _showNativeWebNotification(NotificationPayload payload) {
    try {
      const isWeb = bool.fromEnvironment('dart.library.js_util') || identical(0, 0.0);
      if (isWeb) {
        developer.log('Web environment detected. Triggering browser Notification API.');
        triggerBrowserNotification(payload.taskTitle, payload.message);
      }
    } catch (e) {
      developer.log('Native notification not supported on this platform: $e');
    }
  }

  void dispose() {
    _timer?.cancel();
    _notificationStreamController.close();
  }

  String checkPermissionStatus() {
    return checkBrowserNotificationPermission();
  }

  Future<String> requestPermission() async {
    return await askBrowserNotificationPermission();
  }
}
