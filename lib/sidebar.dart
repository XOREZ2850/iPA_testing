// sidebar.dart

import 'package:attendance_app/Complaint_History.dart';
import 'package:flutter/material.dart';
import 'login.dart'; // Import LoginPage for logout redirection
import 'dashboard.dart'; // Import DashboardPage for navigation
import 'complaint.dart'; // Import ComplaintPage for navigation
import 'leaves.dart'; // Import LeavesPage for navigation
import 'change_password.dart'; // Import ChangePasswordPage for navigation
import 'my_pay_slip.dart'; // Import MyPaySlipPage for navigation
import 'my Attendance.dart';
import 'my_travel.dart'; // Import MyTravelPage for navigation
import 'organization_chart.dart'; // Import OrganizationChartPage for navigation
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // For secure storage
import 'package:logger/logger.dart'; // For logging
import 'package:image_picker/image_picker.dart'; // For image picking
import 'package:path_provider/path_provider.dart'; // For accessing device paths
import 'dart:io'; // For file operations
import 'package:path/path.dart' as path; // For path operations
import 'package:permission_handler/permission_handler.dart'; // For handling permissions
import 'package:http/http.dart' as http; // For API calls
import 'dart:convert'; // For JSON decoding
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // For local notifications

class AppDrawer extends StatefulWidget {
  final String username;
  final String? status; // e.g., 'Online' or 'Offline'

  // Constructor with required username and optional status
  const AppDrawer({
    super.key,
    required this.username,
    this.status = 'Online', // Default status
  });

  @override
  _AppDrawerState createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  // Initialize secure storage
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Logger instance
  final Logger _logger = Logger();

  // ImagePicker instance
  final ImagePicker _picker = ImagePicker();

  // Path to the stored avatar image
  File? _avatarImageFile;

  // Light/Dark mode toggle
  bool _isDarkMode = false;

  // Notification count and list
  int _notificationCount = 0;
  List<dynamic> _notifications = [];

  // Initialize FlutterLocalNotificationsPlugin
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications(); // Initialize notifications
    _loadAvatarImage();
    _loadDarkModePreference();
    _fetchNotificationCount(); // Fetch notification count on initialization
  }

  // Initialize local notifications
  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(
            '@mipmap/ic_launcher'); // Ensure you have the icon in mipmap

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tapped logic here if needed
      },
    );

    // Request permissions after initialization
    await _requestPermissions();
  }

  // Request notification permissions (especially for iOS)
  Future<void> _requestPermissions() async {
    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  // Show a local notification
  Future<void> _showLocalNotification(int id, String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'new_notification_channel', // channel id
      'New Notifications', // channel name
      channelDescription: 'Channel for new notifications',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _localNotificationsPlugin.show(
      id, // Notification ID
      title, // Notification Title
      body, // Notification Body
      platformChannelSpecifics,
      payload: 'New Notification', // Optional payload
    );
  }

  @override
  void dispose() {
    // Dispose resources if needed
    super.dispose();
  }

  // Load the avatar image from storage
  Future<void> _loadAvatarImage() async {
    try {
      String? imagePath = await _secureStorage.read(key: 'avatarPath');
      if (imagePath != null && await File(imagePath).exists()) {
        setState(() {
          _avatarImageFile = File(imagePath);
        });
        _logger.i('Loaded avatar image from $imagePath');
      } else {
        _logger.w('No avatar image found. Using placeholder.');
      }
    } catch (e) {
      _logger.e('Error loading avatar image: $e');
    }
  }

  // Load dark mode preference from secure storage
  Future<void> _loadDarkModePreference() async {
    try {
      String? darkModePreference = await _secureStorage.read(key: 'isDarkMode');
      setState(() {
        _isDarkMode = darkModePreference == 'true';
      });
    } catch (e) {
      _logger.e('Error loading dark mode preference: $e');
    }
  }

  // Function to pick an image from the gallery
  Future<void> _pickImage() async {
    try {
      // Check and request gallery permissions
      PermissionStatus permissionStatus = await Permission.photos.status;

      if (!permissionStatus.isGranted) {
        permissionStatus = await Permission.photos.request();
        if (!permissionStatus.isGranted) {
          _showError('Gallery access denied. Please enable it from settings.');
          return;
        }
      }

      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // Compress the image to 80% quality
      );

      if (pickedFile != null) {
        _logger.i('Image selected: ${pickedFile.path}');

        // Save the image to app's documents directory
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String avatarsDirPath = path.join(appDir.path, 'avatars');
        final Directory avatarsDir = Directory(avatarsDirPath);

        // Create 'avatars' directory if it doesn't exist
        if (!await avatarsDir.exists()) {
          await avatarsDir.create(recursive: true);
          _logger.i('Created avatars directory at ${avatarsDir.path}');
        }

        // Consistently name the avatar file to overwrite existing ones
        final String savedImagePath = path.join(avatarsDir.path, 'avatar.png');

        final File savedImage =
            await File(pickedFile.path).copy(savedImagePath);
        _logger.i('Image saved to $savedImagePath');

        // Update the state to display the new image
        setState(() {
          _avatarImageFile = savedImage;
        });

        // Persist the image path
        await _secureStorage.write(key: 'avatarPath', value: savedImagePath);
        _logger.i('Avatar path saved to secure storage.');

        // Show a success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );
      } else {
        _logger.w('No image selected.');
        // Optionally, show a message indicating that no image was selected
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No image selected.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );
      }
    } catch (e) {
      _logger.e('Error picking/saving image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update profile picture.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
    }
  }

  // Logout function
  void _logout(BuildContext context) async {
    _logger.d('Logging out. Clearing sensitive data.');

    // Check if biometrics are enabled
    String? biometricsEnabled =
        await _secureStorage.read(key: 'biometricsEnabled');

    if (biometricsEnabled != 'true') {
      // Delete only sensitive keys (tokens). Retain 'biometricsEnabled' flag.
      await _secureStorage.delete(key: 'userId');
      await _secureStorage.delete(key: 'accessToken');
      await _secureStorage.delete(key: 'empId');
      await _secureStorage.delete(key: 'username');
      await _secureStorage.delete(
          key: 'avatarPath'); // Delete avatar path on logout
      await _secureStorage.delete(
          key: 'isDarkMode'); // Delete dark mode preference on logout
    } else {
      // Retain credentials for biometric authentication
      _logger.d('Biometrics enabled. Retaining credentials.');
    }

    // Navigate back to LoginPage with an argument to show SnackBar
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginPage(),
        settings: const RouteSettings(arguments: {'loggedOut': true}),
      ),
    );
  }

  // Show error message using SnackBar
  void _showError(String message) {
    _logger.e('Showing error SnackBar: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.redAccent),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // Fetch notification count from API
  Future<void> _fetchNotificationCount() async {
    try {
      // Retrieve userId and accessToken from secure storage
      String? userId = await _secureStorage.read(key: 'userId');
      String? accessToken = await _secureStorage.read(key: 'accessToken');

      if (userId == null || accessToken == null) {
        _logger.w(
            'User ID or Access Token not found. Cannot fetch notifications.');
        return;
      }

      // Construct the API URL
      final String apiUrl =
          'https://api.teckmech.com:8083/api/GenNotifications/FetchGenNotifications?licsenceId=1&companyId=1&userId=$userId&startIndex=0&endIndex=100';

      // Make the GET request with Authorization header
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        // Decode the JSON response
        final Map<String, dynamic> data = json.decode(response.body);

        int totalNotifications = data['totalNotification'] ?? 0;
        List<dynamic> genNotifications = data['GenNotifications'] ?? [];

        // Determine the number of new notifications
        int newNotificationsCount = 0;

        if (_notifications.isEmpty) {
          newNotificationsCount = totalNotifications;
        } else {
          // Assuming each notification has a unique 'id' field
          List<dynamic> newNotifications =
              genNotifications.where((notification) {
            return !_notifications.any((existing) =>
                existing['id'] ==
                notification['id']); // Adjust 'id' field as per your API
          }).toList();

          newNotificationsCount = newNotifications.length;

          // Update _notifications with the latest fetched notifications
          _notifications = genNotifications;
        }

        setState(() {
          _notificationCount = totalNotifications;
        });

        _logger.i('Fetched $totalNotifications notifications.');

        // If there are new notifications, show a local notification
        if (newNotificationsCount > 0) {
          await _showLocalNotification(
            0, // Notification ID; consider using unique IDs for multiple notifications
            'New Notifications',
            'You have $newNotificationsCount new notification(s).',
          );
        }
      } else {
        _logger.e(
            'Failed to fetch notifications. Status code: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Error fetching notification count: $e');
    }
  }

  // Show notifications dialog
  Future<void> _showNotifications() async {
    try {
      // Retrieve userId and accessToken from secure storage
      String? userId = await _secureStorage.read(key: 'userId');
      String? accessToken = await _secureStorage.read(key: 'accessToken');

      if (userId == null || accessToken == null) {
        _showError('User ID or Access Token not found.');
        return;
      }

      // Construct the API URL
      final String apiUrl =
          'https://api.teckmech.com:8083/api/GenNotifications/FetchGenNotifications?licsenceId=1&companyId=1&userId=$userId&startIndex=0&endIndex=100';

      // Make the GET request with Authorization header
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        // Decode the JSON response
        final Map<String, dynamic> data = json.decode(response.body);

        int totalNotifications = data['totalNotification'] ?? 0;
        List<dynamic> genNotifications = data['GenNotifications'] ?? [];

        if (totalNotifications == 0 || genNotifications.isEmpty) {
          _showError('No new notifications.');
          return;
        }

        setState(() {
          _notificationCount = totalNotifications;
          _notifications = genNotifications;
        });

        // Display notifications in a refined dialog
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              backgroundColor: _isDarkMode ? Colors.grey[850] : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  children: [
                    // Dialog Header
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Notifications ($totalNotifications)',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    // Notifications List
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(8.0),
                        itemCount: genNotifications.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          var notification = genNotifications[index];
                          String message =
                              notification['message'] ?? 'No message';
                          String type =
                              notification['type']?.toLowerCase() ?? 'general';

                          IconData iconData;
                          Color iconColor;

                          switch (type) {
                            case 'complaint':
                              iconData = Icons.report_problem;
                              iconColor = Colors.orangeAccent;
                              break;
                            case 'info':
                              iconData = Icons.info;
                              iconColor = Colors.blueAccent;
                              break;
                            case 'alert':
                              iconData = Icons.warning;
                              iconColor = Colors.redAccent;
                              break;
                            default:
                              iconData = Icons.notifications;
                              iconColor = Colors.grey;
                          }

                          return Card(
                            color: _isDarkMode
                                ? Colors.grey[800]
                                : Colors.grey[100],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: Icon(
                                iconData,
                                color: iconColor,
                                size: 28,
                              ),
                              title: Text(
                                message,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(context); // Close the dialog
                                if (type == 'complaint') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const ComplaintHistoryPage()),
                                  );
                                } else {
                                  // Handle other notification types if needed
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    // Close Button
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Close',
                          style: TextStyle(
                            color:
                                _isDarkMode ? Colors.blueAccent : Colors.blue,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      } else {
        _showError('Failed to fetch notifications. Please try again.');
      }
    } catch (e) {
      _logger.e('Error fetching notifications: $e');
      _showError('An error occurred while fetching notifications.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
        child: Container(
            color: _isDarkMode ? Colors.grey[900] : Colors.white,
            child: ListView(
                padding: EdgeInsets.zero, // Removes default padding
                children: <Widget>[
                  // Custom Drawer Header
                  Container(
                    padding: const EdgeInsets.all(16.0).copyWith(top: 40.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isDarkMode
                            ? [Colors.grey.shade800, Colors.grey.shade700]
                            : [
                                const Color.fromARGB(255, 30, 100, 32),
                                const Color.fromARGB(255, 193, 199, 233)
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          offset: const Offset(0, 4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Section with Avatar, Username, Status, and Notification Icon
                        Row(
                          children: [
                            // Employee Avatar with upload functionality
                            GestureDetector(
                              onTap: _pickImage, // Trigger image picker on tap
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 35,
                                    backgroundImage: _avatarImageFile != null
                                        ? FileImage(_avatarImageFile!)
                                            as ImageProvider
                                        : null,
                                    backgroundColor: Colors.grey[300],
                                    child: _avatarImageFile == null
                                        ? const Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 40,
                                          )
                                        : null,
                                  ),
                                  // Edit Icon Overlay
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.edit,
                                        size: 20,
                                        color: Colors.blueAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20.0),
                            // Username and Status
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Username
                                  Text(
                                    widget.username,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: _isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6.0),
                                  // Status Bar with Notification Icon
                                  Row(
                                    children: [
                                      // Status Indicator Dot
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: widget.status == 'Online'
                                              ? Colors.green
                                              : Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8.0),
                                      Text(
                                        widget.status!,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: _isDarkMode
                                              ? Colors.white70
                                              : Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(width: 8.0),
                                      // Notification Icon with Badge
                                      GestureDetector(
                                        onTap: _showNotifications,
                                        child: Icon(
                                          Icons.notifications,
                                          color: const Color.fromARGB(
                                              255, 197, 61, 61),
                                          size:
                                              24, // Increased size for better visibility
                                        ),
                                      ),
                                      if (_notificationCount > 0)
                                        Positioned(
                                          right: 0,
                                          top: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(1),
                                            decoration: BoxDecoration(
                                              color: Colors.redAccent,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            constraints: const BoxConstraints(
                                              minWidth: 12,
                                              minHeight: 12,
                                            ),
                                            child: Text(
                                              '$_notificationCount',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize:
                                                    8, // Adjusted font size
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Main Menu Section
                  _buildMenuSection(
                    title: 'Main Menu',
                    items: [
                      // Dashboard Menu Item
                      _buildMenuItem(
                        context,
                        icon: Icons.dashboard,
                        iconColor: Colors.blue,
                        title: 'Dashboard',
                        navigateTo: const Dashboard(),
                      ),
                      // Complaint Form Menu Item
                      _buildMenuItem(
                        context,
                        icon: Icons.report_problem,
                        iconColor: Colors.orangeAccent,
                        title: 'Complaint Form',
                        navigateTo: const ComplaintPage(),
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.history,
                        iconColor: Colors.green,
                        title: 'Complaint History',
                        navigateTo: const ComplaintHistoryPage(),
                      ),
                      const Divider(),
                      // Settings Section
                      _buildMenuSection(
                        title: 'Settings',
                        items: [
                          // Light/Dark Mode Toggle
                          ListTile(
                            leading: Icon(
                              _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                              color: _isDarkMode
                                  ? Colors.grey.shade700
                                  : Colors.yellow.shade700,
                              size: 28,
                            ),
                            title: Text(
                              'Dark Mode',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color:
                                    _isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            trailing: Switch(
                              value: _isDarkMode,
                              onChanged: (value) async {
                                setState(() {
                                  _isDarkMode = value;
                                });
                                // Save dark mode preference
                                await _secureStorage.write(
                                    key: 'isDarkMode', value: value.toString());
                                // Optionally, trigger theme change across the app
                              },
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      // Account Section
                      _buildMenuSection(
                        title: 'Account',
                        items: [
                          // Logout Menu Item
                          _buildMenuItem(
                            context,
                            icon: Icons.logout,
                            iconColor: Colors.redAccent,
                            title: 'Logout',
                            onTap: () => _logout(context),
                          ),
                          // Change Password Menu Item
                          _buildMenuItem(
                            context,
                            icon: Icons.lock,
                            iconColor: Colors.blueGrey,
                            title: 'Change Password',
                            navigateTo: const ChangePasswordPage(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ])));
  }

  // Helper method to build menu sections
  Widget _buildMenuSection({
    required String title,
    required List<Widget> items,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          // Menu Items
          ...items,
        ],
      ),
    );
  }

  // Helper method to build individual menu items
  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    Widget? navigateTo,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode
                ? Colors.black26
                : Colors.black12, // Darker shadow for dark mode
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: iconColor, size: 28),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: _isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        onTap: onTap ??
            () {
              Navigator.pop(context); // Close the drawer
              if (navigateTo != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => navigateTo),
                );
              }
            },
        // Adding hover effect for web/desktop
        hoverColor: _isDarkMode
            ? Colors.grey.shade700
            : Colors.grey.shade200, // Adjust hover color based on theme
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
