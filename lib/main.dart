// lib/main.dart

import 'package:flutter/material.dart';
import 'company_selection.dart'; // Company Selection Screen
import 'login.dart'; // Login Page
import 'homepage.dart'; // Home Page
import 'complaint.dart'; // Complaint Page
import 'api_service.dart'; // ApiService Singleton
import 'notifications.dart'; // Notification Service
import 'my_pay_slip.dart';
import 'sidebar.dart';

// Define a global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? baseUrl;

  try {
    // Attempt to load base_url into ApiService
    await ApiService.loadBaseUrl();
    baseUrl = ApiService.getBaseUrl();
    print('main.dart: baseUrl loaded: $baseUrl');
  } catch (e) {
    // base_url not set; will navigate to Company Selection
    print('main.dart: baseUrl not set.');
    baseUrl = null;
  }

  // Initialize Notification Service
  final NotificationService notificationService = NotificationService();
  await notificationService.initialize();

  // Schedule the Morning and Evening Notifications with payloads
  notificationService.scheduleDailyNotification(
    id: 1,
    hour: 9,
    minute: 50,
    title: "Morning Reminder 🌞",
    body: "Good morning! Time to check in and start your day with a smile! 😊",
    payload: 'morning_reminder',
  );

  notificationService.scheduleDailyNotification(
    id: 2,
    hour: 18,
    minute: 30,
    title: "Evening Reminder 🌜",
    body: "Great job today! Don't forget to check out and relax! 🛋️",
    payload: 'evening_reminder',
  );

  runApp(MyApp(baseUrl: baseUrl));
}

class MyApp extends StatelessWidget {
  final String? baseUrl;

  const MyApp({super.key, this.baseUrl});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Assign the navigator key
      debugShowCheckedModeBanner: false,
      title: 'Modern Flutter App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // Determine the initial route based on the presence of baseUrl
      initialRoute: baseUrl == null ? '/company-selection' : '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/home': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          if (args != null && args is String) {
            return HomePage(username: args);
          } else {
            return const LoginPage();
          }
        },
        '/complaint': (context) => ComplaintPage(),
        '/company-selection': (context) => CompanySelectionScreen(),
      },
    );
  }
}
