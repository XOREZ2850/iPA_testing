// lib/notifications.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart'; // Needed for context
import 'package:url_launcher/url_launcher.dart'; // To open settings

/// A service class to manage local notifications.
class NotificationService {
  // Singleton pattern to ensure a single instance
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  // FlutterLocalNotificationsPlugin instance
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Initializes the notification settings for Android.
  Future<void> initialize() async {
    // Initialize timezone data
    tz.initializeTimeZones();

    // Set the local location to Asia/Karachi (Islamabad, Pakistan)
    tz.setLocalLocation(tz.getLocation('Asia/Karachi'));

    print('Time zone set to: Asia/Karachi');

    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(
            '@mipmap/ic_launcher'); // Update if using a custom icon

    // Combined initialization settings (excluding iOS/macOS)
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      // Omitting iOS and macOS settings since focusing on Android
    );

    // Initialize the plugin
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onSelectNotification,
    );

    // Request notification permissions (required for Android 13+)
    await _requestNotificationPermissions();
  }

  /// Requests notification permissions on Android 13+.
  Future<void> _requestNotificationPermissions() async {
    // Only request permissions on Android 13+ (API level 33+)
    const int android13 = 33;
    final int currentApiVersion = await _getAndroidVersion();

    if (currentApiVersion >= android13) {
      var status = await Permission.notification.status;
      if (!status.isGranted) {
        status = await Permission.notification.request();
        if (status.isGranted) {
          print('Notification permission granted.');
        } else {
          print('Notification permission denied.');
          // Optionally, inform the user about limited functionality
        }
      } else {
        print('Notification permission already granted.');
      }
    } else {
      // Permissions are granted by default on Android versions below 13
      print(
          'Notification permissions are automatically granted on this Android version.');
    }
  }

  /// Retrieves the current Android API version.
  Future<int> _getAndroidVersion() async {
    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      return androidInfo.version.sdkInt;
    } catch (e) {
      print('Error retrieving Android version: $e');
      return 0; // Default to a version below 33 (Android 13)
    }
  }

  /// Schedules a daily notification at the specified [hour] and [minute].
  Future<void> scheduleDailyNotification({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final scheduledDate = _nextInstanceOfTime(hour, minute);
      print('Scheduling notification "$title" at $scheduledDate');

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id, // Notification ID
        title, // Notification Title
        body, // Notification Body
        scheduledDate, // Scheduled Time
        NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_notifications', // Channel ID
            'Daily Notifications', // Channel Name
            channelDescription: 'Daily notification channel for reminders',
            importance: Importance.high,
            priority: Priority.high,
            // Optional: Customize the notification sound, icon, etc.
          ),
        ),
        androidScheduleMode:
            AndroidScheduleMode.inexact, // Use inexact scheduling
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
        payload: payload, // Payload for handling notification taps
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      print('Scheduled notification: $title at $hour:$minute');
    } catch (e) {
      print('Error scheduling notification: $e');
      // Optionally, notify the user or take corrective action
    }
  }

  /// Calculates the next instance of the specified [hour] and [minute].
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Handles notification taps.
  Future<void> onSelectNotification(
      NotificationResponse notificationResponse) async {
    final String? payload = notificationResponse.payload;
    // Handle notification tapped logic here
    print('Notification Tapped with payload: $payload');

    // Removed navigation logic to prevent automatic navigation
    // You can implement other non-navigational actions here if desired
  }

  /// Cancels all scheduled notifications.
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    print('All notifications canceled.');
  }

  /// (Optional) If your app requires exact alarms, implement this method to guide users to grant the permission.
  Future<void> requestExactAlarmPermission(BuildContext context) async {
    const int android13 = 33;
    final int currentApiVersion = await _getAndroidVersion();

    if (currentApiVersion >= android13) {
      // Inform the user why the exact alarm is necessary
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Enable Exact Alarms'),
            content: Text(
                'To ensure timely notifications, please grant exact alarm permissions in settings.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openExactAlarmSettings();
                },
                child: Text('Enable'),
              ),
            ],
          );
        },
      );
    }
  }

  /// Opens the Exact Alarm permission settings screen.
  Future<void> _openExactAlarmSettings() async {
    const String packageName =
        'com.example.attendance_app'; // Replace with your actual package name

    // Attempt to open the Exact Alarm settings for your app
    final Uri exactAlarmUri = Uri(
      scheme: 'android-app',
      host: 'com.android.settings',
      path: '/exact_alarm',
      queryParameters: {
        'package': packageName,
      },
    );

    if (await canLaunchUrl(exactAlarmUri)) {
      await launchUrl(exactAlarmUri);
    } else {
      // Fallback if the exact alarm settings URI is not supported
      final Uri fallbackUri = Uri.parse(
          'https://play.google.com/store/apps/details?id=$packageName');
      await launchUrl(fallbackUri);
    }
  }
}
