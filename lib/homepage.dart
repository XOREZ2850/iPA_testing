// ignore_for_file: unused_local_variable

import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui; // For image processing

import 'package:attendance_app/change_password.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart'; // For geolocation
import 'package:geocoding/geocoding.dart'; // For reverse geocoding
import 'package:camera/camera.dart'; // For camera functionality
import 'package:uuid/uuid.dart'; // For unique IDs
import 'package:sqflite/sqflite.dart'; // For SQLite
import 'package:path/path.dart' as p; // For path operations
import 'package:permission_handler/permission_handler.dart'; // For permissions
import 'package:url_launcher/url_launcher.dart'; // For launching URLs
import 'package:path_provider/path_provider.dart'; // For determining local paths
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Use secure storage
import 'package:logger/logger.dart'; // For logging

import 'login.dart'; // Import LoginPage for redirection
import 'complaint.dart'; // Import ComplaintPage for navigation
import 'sidebar.dart'; // Import the AppDrawer
import 'advance_search.dart'; // Import AdvanceSearchPage for navigation
import 'api_service.dart'; // Import ApiService class

class HomePage extends StatefulWidget {
  final String username;

  const HomePage({super.key, required this.username});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  // Attendance variables
  String? checkInTime;
  String? checkOutTime;
  Database? _database;
  String? userId;
  String? weatherDescription;
  double? temperature;
  Position? _currentPosition; // To store current position

  // Camera variables
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCameraActive = false; // Tracks if camera preview is active
  bool _isCheckIn = true; // Tracks if it's check-in or check-out
  Position? currentPosition;

  // Variables for KPI card animations
  bool _isHrCardPressed = false;
  bool _isJobCardPressed = false;

  // Initialize secure storage
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  // Logger instance
  final Logger _logger = Logger();

  // User status (e.g., 'Online' or 'Offline')
  final String _status = 'Online'; // Default status

  // Variables to hold permissions and track KPI visibility
  List<dynamic>? _permissions; // To store the list of permissions
  bool _hasKpiPermission = false; // To track if KPI features should be shown

  // Initialization state
  bool _isInitialized = false;

  // **1. Defined Multiple Gradient Themes**
  final List<LinearGradient> _gradientThemes = [
    const LinearGradient(
      colors: [Color(0xFFE1BEE7), Colors.white],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    const LinearGradient(
      colors: [Color.fromARGB(255, 143, 169, 240), Colors.white],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    const LinearGradient(
      colors: [
        Color.fromARGB(237, 248, 151, 151),
        Color.fromARGB(255, 240, 237, 237)
      ],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ),
    const LinearGradient(
      colors: [
        Color.fromARGB(255, 152, 248, 160),
        Color.fromARGB(255, 255, 255, 255)
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    // We can add more gradients as needed
  ];

  // Currently selected gradient index
  int _selectedGradientIndex = 0;

  // Variables to store location names
  String? checkInLocationName;
  String? checkOutLocationName;
  String? checkInLocationCoordinates;
  String? checkOutLocationCoordinates;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add observer
    _initializeApp(); // Initialize app asynchronously
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove observer
    _cameraController?.dispose();
    super.dispose();
  }

  // Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cameraController?.dispose();
      setState(() {
        _isCameraInitialized = false;
      });
    } else if (state == AppLifecycleState.resumed) {
      _initializeCameraInBackground(); // Re-initialize camera when app resumes
    }
  }

  // Initialize the entire app asynchronously
  Future<void> _initializeApp() async {
    await _initializePermissions();
    await _initDatabase();
    await _fetchWeather();
    await _loadPermissions(); // Load permissions
    await _loadSelectedThemeIndex(); // Load saved theme index
    setState(() {
      _isInitialized = true;
    });
  }

  // Initialize permissions and cameras
  Future<void> _initializePermissions() async {
    // Request necessary permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.location,
      Permission.storage, // Added storage permission
    ].request();

    if (statuses[Permission.camera] != PermissionStatus.granted ||
        statuses[Permission.location] != PermissionStatus.granted ||
        statuses[Permission.storage] != PermissionStatus.granted) {
      _showErrorMessage('Required permissions are not granted.');
      return;
    }

    // Permissions granted
    await _initializeCameraInBackground();
  }

  // Initialize the camera in the background
  Future<void> _initializeCameraInBackground() async {
    // Ensure permissions are granted before initializing
    var cameraStatus = await Permission.camera.status;
    var locationStatus = await Permission.location.status;
    var storageStatus = await Permission.storage.status;

    if (!cameraStatus.isGranted ||
        !locationStatus.isGranted ||
        !storageStatus.isGranted) {
      _logger.e('Necessary permissions are not granted.');
      return;
    }

    // Proceed to initialize the camera
    await _initializeCamera();
  }

  // Initialize the camera with retry mechanism
  Future<void> _initializeCamera({int retryCount = 5}) async {
    for (int attempt = 1; attempt <= retryCount; attempt++) {
      try {
        // Dispose existing controller if any
        if (_cameraController != null) {
          await _cameraController!.dispose();
          _cameraController = null;
        }

        final cameras = await availableCameras();
        if (cameras.isEmpty) {
          throw Exception('No cameras available');
        }

        final frontCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
            orElse: () => cameras.first);

        _cameraController = CameraController(
          frontCamera,
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (!mounted) return;
        setState(() {
          _isCameraInitialized = true;
        });
        _logger.i('Camera initialized successfully.');
        return; // Exit after successful initialization
      } catch (e) {
        _logger.e('Camera initialization attempt $attempt failed: $e');
        if (attempt == retryCount) {
          _showErrorMessage(
              'Failed to initialize camera after $retryCount attempts.');
        } else {
          await Future.delayed(
              const Duration(seconds: 2)); // Wait before retrying
        }
      }
    }
  }

  // Initialize the SQLite database
  Future<void> _initDatabase() async {
    try {
      String path = p.join(await getDatabasesPath(), 'attendance.db');
      _database = await openDatabase(
        path,
        version: 5, // Incremented version to handle new column (job_category)
        onCreate: (db, version) async {
          await db.execute('''
              CREATE TABLE attendance(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT,
                username TEXT,
                checkin_time TEXT,
                checkout_time TEXT,
                guid TEXT,
                async_field TEXT,
                checkin_location TEXT,
                checkout_location TEXT,
                image_path TEXT
              )
            ''');

          await db.execute('''
              CREATE TABLE kpi(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT,
                username TEXT,
                kpi_type TEXT,
                kpi_time TEXT,
                employee_name TEXT,
                image_path TEXT,
                job_category TEXT, -- Added the missing column
                submission_type INTEGER
              )
            ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('''
                CREATE TABLE kpi(
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  user_id TEXT,
                  username TEXT,
                  kpi_type TEXT,
                  kpi_time TEXT,
                  employee_name TEXT,
                  image_path TEXT
                )
              ''');
          }
          if (oldVersion < 3) {
            // Added image_path column that didn't exist
            await db.execute('''
                ALTER TABLE attendance ADD COLUMN image_path TEXT
              ''');
          }
          if (oldVersion < 4) {
            // Add submission_type column to kpi table
            await db.execute('''
                ALTER TABLE kpi ADD COLUMN submission_type INTEGER
              ''');
          }
          if (oldVersion < 5) {
            // Add job_category column to kpi table
            await db.execute('''
                ALTER TABLE kpi ADD COLUMN job_category TEXT
              ''');
          }
        },
      );
      await _retrieveOrCreateUserId();
      await _fetchLatestAttendance();
      _logger.i('Database initialized successfully.');
    } catch (e) {
      _logger.e('Error initializing database: $e');
      _showErrorMessage('Failed to initialize the database.');
    }
  }

  Future<String> _getLocationName(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        String locationName =
            '${placemark.subThoroughfare ?? ''} ${placemark.thoroughfare ?? ''}, '
            '${placemark.subLocality ?? ''}, '
            '${placemark.locality ?? ''}, '
            '${placemark.administrativeArea ?? ''}, '
            '${placemark.postalCode ?? ''}, '
            '${placemark.country ?? ''}';
        // Remove unnecessary commas and spaces
        locationName = locationName.replaceAll(RegExp(r'\s*,\s*'), ', ').trim();
        locationName = locationName.replaceAll(RegExp(r'^,|,$'), '');
        return locationName;
      } else {
        return 'Unknown Location';
      }
    } catch (e) {
      _logger.e('Error in reverse geocoding: $e');
      return 'Unknown Location';
    }
  }

  // Retrieve existing userId or create a new one
  Future<void> _retrieveOrCreateUserId() async {
    if (_database == null) return;

    // Check if any user_id exists
    List<Map<String, dynamic>> result = await _database!.query(
      'attendance',
      columns: ['user_id'],
      limit: 1,
    );

    if (result.isNotEmpty && result[0]['user_id'] != null) {
      setState(() {
        userId = result[0]['user_id'];
      });
      _logger.i('Existing user ID retrieved: $userId');
    } else {
      // Generate a new userId and insert a dummy record to store it
      String newUserId = const Uuid().v4();
      setState(() {
        userId = newUserId;
      });
      _logger.i('New user ID generated: $userId');
      // Insert a dummy attendance record with no check-in/check-out
      await _database!.insert(
        'attendance',
        {
          'user_id': userId,
          'username': widget.username,
          'checkin_time': '',
          'checkout_time': '',
          'guid': const Uuid().v4(),
          'async_field': 'false',
          'checkin_location': '',
          'checkout_location': '',
          'image_path': '',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // Fetch the latest attendance record to display check-in/check-out times
  Future<void> _fetchLatestAttendance() async {
    if (_database == null || userId == null) return;

    List<Map<String, dynamic>> records = await _database!.query(
      'attendance',
      where: 'user_id = ? AND checkin_time != ""',
      whereArgs: [userId],
      orderBy: 'checkin_time DESC',
      limit: 1,
    );

    if (records.isNotEmpty) {
      setState(() {
        checkInTime = records[0]['checkin_time'].isNotEmpty
            ? records[0]['checkin_time']
            : null;
        checkOutTime = records[0]['checkout_time'].isNotEmpty
            ? records[0]['checkout_time']
            : null;
        // Fetch and set location names using reverse geocoding
        if (records[0]['checkin_location'] != null &&
            records[0]['checkin_location'].isNotEmpty) {
          List<String> parts = records[0]['checkin_location'].split(',');
          if (parts.length == 2) {
            double lat = double.tryParse(parts[0].trim()) ?? 0.0;
            double lng = double.tryParse(parts[1].trim()) ?? 0.0;
            _setLocationName(lat, lng, isCheckIn: true);
          }
        }
        if (records[0]['checkout_location'] != null &&
            records[0]['checkout_location'].isNotEmpty) {
          List<String> parts = records[0]['checkout_location'].split(',');
          if (parts.length == 2) {
            double lat = double.tryParse(parts[0].trim()) ?? 0.0;
            double lng = double.tryParse(parts[1].trim()) ?? 0.0;
            _setLocationName(lat, lng, isCheckIn: false);
          }
        }
      });
      _logger.i('Latest attendance record fetched.');
    }
  }

  Future<void> _setLocationName(double lat, double lng,
      {required bool isCheckIn}) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;

        // Construct a detailed address
        String locationName = [
          placemark.name,
          placemark.subThoroughfare,
          placemark.thoroughfare,
          placemark.subLocality,
          placemark.locality,
          placemark.administrativeArea,
          placemark.postalCode,
          placemark.country,
        ].where((element) => element != null && element.isNotEmpty).join(', ');

        setState(() {
          if (isCheckIn) {
            checkInLocationName = locationName;
          } else {
            checkOutLocationName = locationName;
          }
        });
      }
    } catch (e) {
      _logger.e('Error in reverse geocoding: $e');
      setState(() {
        if (isCheckIn) {
          checkInLocationName = 'Unknown Location';
        } else {
          checkOutLocationName = 'Unknown Location';
        }
      });
    }
  }

  // Function to retrieve userId from secure storage
  Future<String?> getUserId() async {
    return await _secureStorage.read(key: 'userId');
  }

  // Function to retrieve accessToken from secure storage
  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: 'accessToken');
  }

  // Function to retrieve empId from secure storage
  Future<String?> getEmpId() async {
    return await _secureStorage.read(key: 'empId');
  }

  // Determine the current position of the device
  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Location permissions are permanently denied. We cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  // Define the variables for storing the timestamp and card state
  DateTime? lastCheckInCheckOutTime;
  bool isCardDisabled = false;

  // Handle check-in and check-out actions
  void _handleCheck(bool isCheckIn) async {
    if (!_isInitialized) {
      _showErrorMessage('App is still initializing. Please wait.');
      return;
    }
    // Checking if 05 minutes have passed since the last check-in/check-out
    if (lastCheckInCheckOutTime != null &&
        DateTime.now().difference(lastCheckInCheckOutTime!).inMinutes < 10) {
      _showErrorMessage('You must wait 05 minutes after your last action.');
      return;
    }
    try {
      Position position = await _determinePosition();

      if (!isCheckIn) {
        // It's a check-out, verify location
        List<Map<String, dynamic>> records = await _database!.query(
          'attendance',
          where: 'user_id = ? AND checkin_time != ""',
          whereArgs: [userId],
          orderBy: 'checkin_time DESC',
          limit: 1,
        );

        if (records.isNotEmpty) {
          String? lastCheckInLocation = records[0]['checkin_location'];
          if (lastCheckInLocation != null && lastCheckInLocation.isNotEmpty) {
            List<String> parts = lastCheckInLocation.split(',');
            if (parts.length == 2) {
              double lastLat = double.tryParse(parts[0].trim()) ?? 0.0;
              double lastLng = double.tryParse(parts[1].trim()) ?? 0.0;
              double currentLat = position.latitude;
              double currentLng = position.longitude;
              double distance = Geolocator.distanceBetween(
                lastLat,
                lastLng,
                currentLat,
                currentLng,
              );
              if (distance > 50) {
                // Threshold of 50 meters
                _showErrorMessage(
                    'Your current location differs significantly from your check-in location. Check-out denied.');
                return; // Prevent checkout
              }
            }
          }
        } else {
          // No check-in record found
          _showErrorMessage('No check-in record found. Cannot check out.');
          return;
        }
      }

      // Performed reverse geocoding to obtain location name
      String locationName =
          await _getLocationName(position.latitude, position.longitude);

      setState(() {
        currentPosition = position;
        _isCheckIn = isCheckIn;
        _isCameraActive = true; // Activate camera immediately

        // Record the current time of the check-in/check-out action
        lastCheckInCheckOutTime = DateTime.now();

        // Set location name based on action
        if (isCheckIn) {
          checkInLocationName = locationName;
          checkOutLocationName = null; // Reset check-out location name
        } else {
          checkOutLocationName = locationName;
        }

        // Disable the card temporarily (for 05 minutes)
        isCardDisabled = true;
      });
      _logger.i('${isCheckIn ? 'Check-In' : 'Check-Out'} initiated.');
      // Set a timer to re-enable the card after 05 minutes
      Future.delayed(const Duration(minutes: 5), () {
        setState(() {
          isCardDisabled = false; // Re-enable the card after 05 minutes
        });
      });
    } catch (e) {
      _logger.e('Error during check-in/out: $e');
      _showErrorMessage(
          'Failed to initiate ${isCheckIn ? 'Check-In' : 'Check-Out'}. Please try again.');
    }
  }

  // Enhanced camera initialization with retry mechanism
  Future<void> _initializeCameraWithRetry({int retryCount = 5}) async {
    for (int attempt = 1; attempt <= retryCount; attempt++) {
      try {
        // Dispose existing controller if any
        if (_cameraController != null) {
          await _cameraController!.dispose();
          _cameraController = null;
        }

        final cameras = await availableCameras();
        if (cameras.isEmpty) {
          throw Exception('No cameras available');
        }

        final frontCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
            orElse: () => cameras.first);

        _cameraController = CameraController(
          frontCamera,
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (!mounted) return;
        setState(() {
          _isCameraInitialized = true;
        });
        _logger.i('Camera initialized successfully.');
        return; // Exit after successful initialization
      } catch (e) {
        _logger.e('Camera initialization attempt $attempt failed: $e');
        if (attempt == retryCount) {
          _showErrorMessage(
              'Failed to initialize camera after $retryCount attempts.');
        } else {
          await Future.delayed(
              const Duration(seconds: 2)); // Wait before retrying
        }
      }
    }
  }

  // **[No changes in the _sendDataToServer and related functions]**

  // Send data to the server with specified type
  Future<void> _sendDataToServer({
    required int type, // 1 or 2 for Check-In/Check-Out
    required String imagePath,
    required Position position,
    required bool isKpi, // New parameter to distinguish KPI from Attendance
  }) async {
    String jobKpiType = "0";
    String kpiType;
    int attendanceType = 0;

    if (isKpi) {
      // HR KPI
      kpiType = "1"; // Correctly setting KPI_TYPE to 1 for HR KPI
      attendanceType = type; // 1 for Check-In, 2 for Check-Out
    } else {
      // Attendance
      kpiType = "0"; // KPI_TYPE remains 0 for Attendance
      attendanceType = type; // 1 for Check-In, 2 for Check-Out
    }

    if (type == 5) {
      // Job KPI
      jobKpiType = await _getJobKpiType();
      kpiType = "2";
      attendanceType = 4;
    }

    String? storedUserId = await getUserId();
    String? accessToken = await getAccessToken();

    if (storedUserId == null || accessToken == null) {
      _showErrorMessage('User ID or access token not found.');
      return;
    }

    try {
      // **Logging the KPI and Attendance Types**
      _logger.i('Preparing to send data to server:');
      _logger.i('kpi_type: $kpiType');
      _logger.i('attendance_type: $attendanceType');
      _logger.i('jobKpiType: $jobKpiType');
      _logger.i('Image Path: $imagePath');
      _logger.i(
          'Position: Latitude=${position.latitude}, Longitude=${position.longitude}');

      // Dynamically fetch the base URL using ApiService
      String baseUrl = ApiService.getBaseUrl();

      // Define the endpoint relative to the base URL
      String endpointUrl =
          '${baseUrl}api/GenNotifications/UpdateAttendanceWithMOb';

      final uri = Uri.parse(endpointUrl).replace(queryParameters: {
        'UserID': storedUserId,
        'Latitude': position.latitude.toString(),
        'Longitude': position.longitude.toString(),
        'AttendanceType': attendanceType.toString(),
        'EMP_ATTN_PIC_PATH': imagePath,
        'JOB_KPI_TYPE': jobKpiType,
        'KPI_TYPE': kpiType, // Now correctly set based on isKpi
      });

      _logger.i('Sending PUT request to: $uri');

      final response = await http.put(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      _logger.i('Received response: Status Code ${response.statusCode}');

      if (response.body.isNotEmpty) {
        final responseJson = json.decode(response.body);
        _logger.i('Server Response: $responseJson');

        // Check for success and extract the "Source" value
        if (response.statusCode == 200 && responseJson.containsKey('Source')) {
          String source = responseJson['Source'];

          // **Logging the Source**
          _logger.i('Source received from server: $source');

          // Call the image upload API with the new "Source" parameter
          await _uploadImageToServer(
            imagePath,
            'attendance_${DateTime.now().millisecondsSinceEpoch}.jpg',
            storedUserId,
            attendanceType,
            source,
          );
        } else {
          _logger.w('Source key missing in server response.');
        }
      } else {
        _logger.w('Server Response Body is empty.');
      }
    } catch (e) {
      _logger.e('Error updating data on server: $e');
    }
  }

  // Upload image to the server with specified filename, EMP_CODE, ATTENDANCE_TYPE, and Source
  Future<void> _uploadImageToServer(
    String imagePath,
    String filename,
    String empCode,
    int attendanceType,
    String source,
  ) async {
    String baseUrl = ApiService.getBaseUrl();

    String apiUrl = '${baseUrl}api/GenNotifications/uploadimageupdated';
    String? accessToken = await getAccessToken();

    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.headers['Authorization'] = 'Bearer $accessToken';

      // Assign the desired filename based on the action
      request.files.add(await http.MultipartFile.fromPath(
        'avatar',
        imagePath,
        filename: filename,
      ));

      // Add EMP_CODE, ATTENDANCE_TYPE, and Source fields
      request.fields['EMP_CODE'] =
          (await _secureStorage.read(key: 'username')).toString();
      request.fields['ATTENDANCE_TYPE'] = attendanceType.toString();
      request.fields['Source'] = source;
      // Added KPI_TYPE
      request.fields['KPI_TYPE'] =
          "0"; // Assuming KPI_TYPE is needed // Include the extracted Source

      var response = await request.send();

      // Parse and print the JSON response
      final responseBody = await response.stream.bytesToString();
      if (responseBody.isNotEmpty) {
        final responseJson = json.decode(responseBody);
        _logger.i('Image Upload Response: $responseJson');
      } else {
        _logger.w('Image Upload Response Body is empty.');
      }

      if (response.statusCode == 200) {
        _logger.i('Image successfully saved to server');
      } else {
        _logger.e('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Error uploading image: $e');
    }
  }

  // Get JOB_KPI_TYPE based on the selected job category
  Future<String> _getJobKpiType() async {
    try {
      // Retrieve Job KPI Type from secure storage
      String? jobKpiType = await _secureStorage.read(key: 'selectedJobKpiType');
      if (jobKpiType != null && jobKpiType.isNotEmpty) {
        return jobKpiType;
      } else {
        _logger.w(
            'No JobKpiType found in secure storage. Returning default value "0".');
        return "0"; // Default value if not found
      }
    } catch (e) {
      _logger.e('Error fetching JobKpiType: $e');
      return "0"; // Fallback to "0" in case of any error
    }
  }

  // Overlay text onto image using dart:ui
  Future<void> _overlayTextOnImage(String imagePath, String text) async {
    try {
      // Load the image as bytes
      File imageFile = File(imagePath);
      Uint8List imageBytes = await imageFile.readAsBytes();

      ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
      ui.FrameInfo frameInfo = await codec.getNextFrame();
      ui.Image originalImage = frameInfo.image;

      // Create a canvas to draw on
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Draw the original image onto the canvas
      canvas.drawImage(originalImage, Offset.zero, Paint());
      // Define padding around text
      const double padding = 8.0;

      // Prepare the text style
      final textStyle = ui.TextStyle(
        color: Colors.orange, // Orange text
        fontSize: 24,
        background: Paint()
          ..color =
              Colors.transparent, // Transparent since we'll draw a background
      );

      // Prepare the paragraph style
      final paragraphStyle = ui.ParagraphStyle(
        textDirection: ui.TextDirection.ltr,
      );

      // Build the paragraph with the text
      final paragraphBuilder = ui.ParagraphBuilder(paragraphStyle)
        ..pushStyle(textStyle)
        ..addText(text);

      final paragraph = paragraphBuilder.build()
        ..layout(ui.ParagraphConstraints(
            width: originalImage.width.toDouble() - 20));

      // Calculate background rectangle size
      final Rect backgroundRect = Rect.fromLTWH(
        10,
        10,
        paragraph.width + padding * 2,
        paragraph.height + padding * 2,
      );

      // Draw green rectangle as background
      final Paint backgroundPaint = Paint()
        ..color = const Color.fromARGB(255, 13, 51, 14);
      canvas.drawRect(backgroundRect, backgroundPaint);
      // Draw the text onto the canvas
      canvas.drawParagraph(paragraph, Offset(10 + padding, 10 + padding));

      // End recording and get the new image
      final picture = recorder.endRecording();
      final newImage =
          await picture.toImage(originalImage.width, originalImage.height);
      final pngBytes =
          await newImage.toByteData(format: ui.ImageByteFormat.png);

      // Save the image to the file
      await imageFile.writeAsBytes(pngBytes!.buffer.asUint8List());
    } catch (e) {
      _logger.e('Error overlaying text on image: $e');
    }
  }

  // Function to get the directory for storing images
  Future<String> _getImageDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final imageDir = Directory('${directory.path}/attendance_images');
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    return imageDir.path;
  }

  // Function to save the image locally and return the new path
  Future<String> _saveImageLocally(XFile image) async {
    final imageDir = await _getImageDirectory();
    final String newPath =
        '$imageDir/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final File newImage = await File(image.path).copy(newPath);
    return newImage.path;
  }

  // Capture image, save attendance record, overlay text, and upload image
  Future<void> _captureImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _showErrorMessage('Camera is not initialized.');
      return;
    }

    if (currentPosition == null) {
      _showErrorMessage('Location is not available.');
      return;
    }

    try {
      // Capture the image
      XFile image = await _cameraController!.takePicture();
      _logger.i('Image captured at: ${image.path}');

      // Save the image locally and get the new path
      String localImagePath = await _saveImageLocally(image);
      _logger.i('Image saved locally at: $localImagePath');

      // Close the camera preview
      setState(() {
        _isCameraActive = false;
      });

      String coordinates = currentPosition != null
          ? '${currentPosition!.latitude.toStringAsFixed(5)}, ${currentPosition!.longitude.toStringAsFixed(5)}'
          : 'Unknown Location';

      String overlayText =
          'User: ${widget.username}\nTime: ${DateFormat('yyyy-MM-dd hh:mm a').format(DateTime.now())}\nLocation: $coordinates \nLocation: ${_isCheckIn ? (checkInLocationName ?? 'Unknown Location') : (checkOutLocationName ?? 'Unknown Location')}';
      await _overlayTextOnImage(localImagePath, overlayText);

      // Determine the type based on check-in/check-out
      int type;
      String filename;

      if (_hasJobKpiSubmission()) {
        // Job KPI Submission
        type = 5; // Assuming type 5 for Job KPI
        filename =
            'job_kpi_${DateTime.now().millisecondsSinceEpoch}.jpg'; // Unique filename
      } else {
        type = _isCheckIn ? 1 : 2; // 1 for Check-In, 2 for Check-Out
        filename = _isCheckIn
            ? 'checkin_pic.jpg'
            : 'checkout_pic.jpg'; // Assign filename based on action
      }

      // Retrieve EMP_CODE from secure storage, default to '00000' if not available
      String empCode = await getEmpCodeForAttendance();

      // Perform server update asynchronously
      await _sendDataToServer(
        type: type,
        imagePath: localImagePath,
        position: currentPosition!,
        isKpi: _hasJobKpiSubmission(), // Set isKpi based on submission
      );

      // Update local database with the image path
      if (_isCheckIn) {
        setState(() {
          checkInTime = DateFormat('hh:mm a').format(DateTime.now());
          checkOutTime = null;
          // Location name is already set during _handleCheck
        });
        await _saveCheckIn(currentPosition!, localImagePath);
        _showSuccessMessage('Check-In successful!');
      } else {
        setState(() {
          checkOutTime = DateFormat('hh:mm a').format(DateTime.now());
          // Location name is already set during _handleCheck
        });
        await _saveCheckOut(currentPosition!, localImagePath);
        _showSuccessMessage('Check-Out successful!');

        // Clear history records older than 12 hours after checkout
        await _clearOldHistory();
      }
    } catch (e) {
      _logger.e('Error capturing image: $e');
      _showErrorMessage('Failed to capture image.');
      setState(() {
        _isCameraActive = false; // Ensure camera is closed on error
      });
    }
  }

  // **New Function: Check if the current submission is Job KPI**
  bool _hasJobKpiSubmission() {
    // Implement your logic to determine if the current submission is Job KPI
    // For example, you might set a flag when opening the Job KPI dialog
    return false; // Placeholder
  }

  // Save check-in data to the database with image path
  Future<void> _saveCheckIn(Position position, String imagePath) async {
    if (_database == null || userId == null) {
      _showErrorMessage('Database not initialized.');
      return;
    }

    try {
      await _database!.insert(
        'attendance',
        {
          'user_id': userId,
          'username': widget.username,
          'checkin_time': checkInTime,
          'checkout_time': '',
          'guid': const Uuid().v4(),
          'async_field': 'true',
          'checkin_location':
              '${position.latitude.toStringAsFixed(5)},${position.longitude.toStringAsFixed(5)}',
          'checkout_location': '',
          'image_path': imagePath, // Store the image path
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _logger.i('Check-In data saved to database.');
    } catch (e) {
      _logger.e('Error saving check-In: $e');
      _showErrorMessage('Failed to save check-In data.');
    }
  }

  // Save check-out data to the database with image path
  Future<void> _saveCheckOut(Position position, String imagePath) async {
    if (_database == null || userId == null) {
      _showErrorMessage('Database not initialized.');
      return;
    }

    try {
      int count = await _database!.update(
        'attendance',
        {
          'checkout_time': checkOutTime,
          'checkout_location':
              '${position.latitude.toStringAsFixed(5)},${position.longitude.toStringAsFixed(5)}',
          'async_field': 'false',
          'image_path': imagePath, // Update the image path
        },
        where: 'user_id = ? AND checkout_time = ""',
        whereArgs: [userId],
      );

      if (count == 0) {
        _showErrorMessage('No active check-In record found for check-out.');
      } else {
        _logger.i('Check-Out data updated in database.');
      }
    } catch (e) {
      _logger.e('Error saving check-Out: $e');
      _showErrorMessage('Failed to save check-Out data.');
    }
  }

  // Function to clear history records older than 12 hours after checkout
  Future<void> _clearOldHistory() async {
    if (_database == null || userId == null) return;

    try {
      DateTime twelveHoursAgo =
          DateTime.now().subtract(const Duration(hours: 12));
      String formattedTime =
          DateFormat('yyyy-MM-dd hh:mm a').format(twelveHoursAgo);

      int deletedCount = await _database!.delete(
        'attendance',
        where:
            'user_id = ? AND checkout_time != "" AND datetime(checkout_time) <= datetime(?)',
        whereArgs: [userId, formattedTime],
      );

      _logger.i('Cleared $deletedCount old history records.');
    } catch (e) {
      _logger.e('Error clearing old history records: $e');
    }
  }

  // Fetch weather information from OpenWeatherMap API
  Future<void> _fetchWeather() async {
    const String apiKey = '1b72ab43c393f08522901ef92b93e168';
    const String city = 'Lahore, Pakistan';
    final String url =
        'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&units=metric';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          weatherDescription = data['weather'][0]['description'];
          temperature = data['main']['temp'];
        });
        _logger.i('Weather data fetched successfully.');
      } else {
        _logger.e('Failed to load weather: ${response.statusCode}');
        throw Exception('Failed to load weather');
      }
    } catch (e) {
      _logger.e('Error fetching weather: $e');
      setState(() {
        weatherDescription = 'Unable to fetch weather';
      });
    }
  }

  // Show error message using SnackBar
  void _showErrorMessage(String message) {
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

  // Show success message using SnackBar
  void _showSuccessMessage(String message) {
    _logger.i('Showing success SnackBar: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
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

  // Open KPI Dialog with callback to refresh History
  void _openKpiDialog(String kpiType) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return KpiDialog(
          kpiType: kpiType,
          username: widget.username,
          database: _database,
          userId: userId,
          onKpiMarked: () {
            // Refresh the History section after a KPI is marked
            setState(() {});
          },
          // Pass the _sendDataToServer function as a callback with type 3 or 4
          sendDataToServer:
              (int type, String imagePath, Position position, bool isKpi) {
            _sendDataToServer(
              type: type,
              imagePath: imagePath,
              position: position,
              isKpi: isKpi,
            );
          },
          uploadImageToServer: (String imagePath, String filename) async {
            // Retrieve EMP_CODE from the selected employee in KpiDialog
            String empCode = await _getEmpCodeForKpi();
            int attendanceType = kpiTypeToAttendanceType(kpiType);
            String source = "0"; // or some default value

            _uploadImageToServer(
                imagePath, filename, empCode, attendanceType, source);
          },
        );
      },
    );
  }

  // Helper method to get EMP_CODE for KPI from KpiDialog
  Future<String> _getEmpCodeForKpi() async {
    // Since KpiDialog handles the selection, ensure that the selected employee's EMP_CODE is accessible
    // This can be done via secure storage or another method depending on your implementation
    // For simplicity, we'll assume it's stored in secure storage under 'empCodeKpi'
    String? empCode = await _secureStorage.read(key: 'empCodeKpi');
    return empCode ?? '00000'; // Default to '00000' if not available
  }

  // Convert KPI type to ATTENDANCE_TYPE
  int kpiTypeToAttendanceType(String kpiType) {
    switch (kpiType) {
      case 'HR':
        return 1;
      case 'Job':
        return 2;
      default:
        return 0; // Undefined type
    }
  }

  // Build status cards for Check-In and Check-Out
  Widget _buildStatusCard(String label, String? time, IconData icon,
      Color iconColor, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(6.0),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28.0, color: iconColor),
              const SizedBox(height: 6.0),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  time ?? '--:--',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4.0),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build HR KPI and Job KPI Cards with improved design
  Widget _buildKpiCards() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // HR KPI Card
        Expanded(
          child: GestureDetector(
            onTapDown: (_) => setState(() => _isHrCardPressed = true),
            onTapUp: (_) => setState(() => _isHrCardPressed = false),
            onTapCancel: () => setState(() => _isHrCardPressed = false),
            onTap: () {
              _openKpiDialog('HR');
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              margin: const EdgeInsets.all(6.0),
              padding: const EdgeInsets.all(16.0),
              transform: Matrix4.identity()
                ..scale(_isHrCardPressed ? 0.98 : 1.0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color.fromARGB(255, 34, 71, 80), Color(0xFF0083B0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.person_add_alt_1, size: 35.0, color: Colors.white),
                  SizedBox(height: 12.0),
                  Text(
                    'Mark HR KPI',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Job KPI Card
        Expanded(
          child: GestureDetector(
            onTapDown: (_) => setState(() => _isJobCardPressed = true),
            onTapUp: (_) => setState(() => _isJobCardPressed = false),
            onTapCancel: () => setState(() => _isJobCardPressed = false),
            onTap: () {
              _openKpiDialog('Job');
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              margin: const EdgeInsets.all(6.0),
              padding: const EdgeInsets.all(16.0),
              transform: Matrix4.identity()
                ..scale(_isJobCardPressed ? 0.98 : 1.0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color.fromARGB(255, 252, 120, 131),
                    Color.fromARGB(255, 253, 203, 132)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.assignment_turned_in,
                      size: 35.0, color: Colors.white),
                  SizedBox(height: 12.0),
                  Text(
                    'Mark Job KPI',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Build attendance and KPI history section
  Widget _buildHistorySection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchAllHistories(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return const Text('Error fetching history records.');
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('No history records found.');
        } else {
          List<Map<String, dynamic>> records = snapshot.data!;
          return Column(
            children: [
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: records.length,
                itemBuilder: (context, index) {
                  var record = records[index];
                  if (record['record_type'] == 'Attendance') {
                    String checkIn = record['checkin_time'] != ''
                        ? record['checkin_time']
                        : '--:--';
                    String checkOut = record['checkout_time'] != ''
                        ? record['checkout_time']
                        : '--:--';
                    String checkInLocationName =
                        record['checkin_location_name'] ??
                            'Click to See on Map';
                    String checkOutLocationName =
                        record['checkout_location_name'] ??
                            'Click to See on Map';
                    String imagePath = record['image_path'] ?? '';

                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.person,
                          color: Colors.blueAccent,
                        ),
                        title: Text(
                          'Check-In: $checkIn',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (record['checkin_location'] != 'N/A') {
                                  _launchMaps(record['checkin_location']);
                                }
                              },
                              child: Text(
                                'Location: $checkInLocationName',
                                style: TextStyle(
                                  color:
                                      checkInLocationName != 'Unknown Location'
                                          ? Colors.blue
                                          : Colors.black54,
                                  decoration:
                                      checkInLocationName != 'Unknown Location'
                                          ? TextDecoration.underline
                                          : TextDecoration.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Check-Out: $checkOut',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (imagePath.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.image, size: 20),
                                    onPressed: () {
                                      _showImageDialog(imagePath);
                                    },
                                  ),
                              ],
                            ),
                            if (record['checkout_location'] != null &&
                                record['checkout_location'].isNotEmpty) ...[
                              GestureDetector(
                                onTap: () {
                                  if (record['checkout_location'] != 'N/A') {
                                    _launchMaps(record['checkout_location']);
                                  }
                                },
                                child: Text(
                                  'Location: $checkOutLocationName',
                                  style: TextStyle(
                                    color: checkOutLocationName !=
                                            'Unknown Location'
                                        ? Colors.blue
                                        : Colors.black54,
                                    decoration: checkOutLocationName !=
                                            'Unknown Location'
                                        ? TextDecoration.underline
                                        : TextDecoration.none,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  } else if (record['record_type'] == 'KPI') {
                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.assignment,
                          color: Colors.blue,
                        ),
                        title: Text(
                            '${record['kpi_type']} KPI marked for ${record['employee_name']}'),
                        subtitle: Text('Submitted on: ${record['kpi_time']}'),
                      ),
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                },
              ),
            ],
          );
        }
      },
    );
  }

  // Launch Google Maps with the provided location
  Future<void> _launchMaps(String location) async {
    final Uri url = Uri.parse('https://maps.google.com/maps?q=$location');
    if (!await launchUrl(url)) {
      _showErrorMessage('Could not launch Maps.');
    }
  }

  // Show image in a dialog
  void _showImageDialog(String imagePath) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: imagePath.startsWith('http')
              ? Image.network(imagePath)
              : Image.file(File(imagePath)),
        );
      },
    );
  }

  // Fetch all history records including Attendance and KPI
  Future<List<Map<String, dynamic>>> _fetchAllHistories() async {
    if (_database == null || userId == null) return [];

    // Fetch attendance records with check-in time, regardless of check-out
    List<Map<String, dynamic>> attendanceRecords = await _database!.query(
      'attendance',
      where: 'user_id = ? AND checkin_time != ""',
      whereArgs: [userId],
      orderBy: 'checkin_time DESC',
    );

    // Fetch KPI records only if the user has permission
    List<Map<String, dynamic>> kpiRecords = [];
    if (_hasKpiPermission) {
      kpiRecords = await _database!.query(
        'kpi',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'kpi_time DESC',
      );
    }

    // Combine and sort all records by time
    List<Map<String, dynamic>> combinedRecords = [];

    for (var record in attendanceRecords) {
      combinedRecords.add({
        'record_type': 'Attendance',
        ...record,
      });
    }

    for (var record in kpiRecords) {
      combinedRecords.add({
        'record_type': 'KPI',
        ...record,
      });
    }

    // Sort combined records by time descending
    combinedRecords.sort((a, b) {
      DateTime aTime = a['record_type'] == 'Attendance'
          ? _parseAttendanceTime(a['checkin_time'])
          : _parseKpiTime(a['kpi_time']);
      DateTime bTime = b['record_type'] == 'Attendance'
          ? _parseAttendanceTime(b['checkin_time'])
          : _parseKpiTime(b['kpi_time']);
      return bTime.compareTo(aTime);
    });

    return combinedRecords;
  }

  // Helper method to parse attendance time
  DateTime _parseAttendanceTime(String time) {
    try {
      return DateFormat('hh:mm a').parse(time);
    } catch (e) {
      _logger.e('Error parsing attendance time: $e');
      return DateTime.now();
    }
  }

  // Helper method to parse KPI time
  DateTime _parseKpiTime(String time) {
    try {
      return DateFormat('yyyy-MM-dd – kk:mm').parse(time);
    } catch (e) {
      _logger.e('Error parsing KPI time: $e');
      return DateTime.now();
    }
  }

  // Load permissions from secure storage
  Future<void> _loadPermissions() async {
    String? permissionsJson = await _secureStorage.read(key: 'permissions');

    if (permissionsJson != null) {
      // Parse the JSON string to a list
      _permissions = jsonDecode(permissionsJson);

      // Check if the specific PERMISION_ID is present
      _hasKpiPermission =
          _checkPermission(22659); // Replace 22659 with your PERMISION_ID

      // Add detailed debug console print
      if (_hasKpiPermission) {
        _logger.i('Permission ID 22659 found in permissions.');
        print('Permission ID 22659 found in permissions.');
      } else {
        _logger.i('Permission ID 22659 not found in permissions.');
        print('Permission ID 22659 not found in permissions.');
      }
    } else {
      // Handle the case where permissions are not available
      _hasKpiPermission = false;
      _logger.i('No permissions found in secure storage.');
      print('No permissions found in secure storage.');
    }
  }

  // Check if the specific permission ID is present
  bool _checkPermission(int permissionId) {
    if (_permissions == null) return false;

    for (var permission in _permissions!) {
      if (permission['PERMISION_ID'] == permissionId) {
        return true;
      }
    }
    return false;
  }

  // Load the selected theme index from secure storage
  Future<void> _loadSelectedThemeIndex() async {
    String? indexStr = await _secureStorage.read(key: 'selectedGradientIndex');
    if (indexStr != null) {
      int? index = int.tryParse(indexStr);
      if (index != null && index >= 0 && index < _gradientThemes.length) {
        setState(() {
          _selectedGradientIndex = index;
        });
        _logger.i('Loaded saved theme index: $_selectedGradientIndex');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If not initialized, show a loading indicator
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Initializing...'),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    String currentDate = DateFormat('MMMM dd, yyyy').format(DateTime.now());

    return Scaffold(
      // Add the Drawer here
      drawer: AppDrawer(
        username: widget.username,
        status: _status, // Pass the user's status
      ),
      body: Stack(
        children: [
          Container(
            // **2. Apply Selected Gradient Theme to Background**
            decoration: BoxDecoration(
              gradient: _gradientThemes[_selectedGradientIndex],
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SMART ERP Text
                      const Text(
                        'TECK MECH',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      // Header with Hello, Username and Theme Dropdown Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hello, ${widget.username}',
                                  style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4.0),
                                Text(
                                  currentDate,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 8.0),
                                // **3. Add the Gradient-Themed Dropdown Button**
                                _buildThemeDropdown(),
                              ],
                            ),
                          ),
                          // Keep the existing menu button
                          Builder(
                            builder: (context) => IconButton(
                              icon:
                                  const Icon(Icons.menu, color: Colors.black87),
                              onPressed: () {
                                Scaffold.of(context).openDrawer();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Weather Information
                      Text(
                        temperature != null && weatherDescription != null
                            ? (DateTime.now().hour >= 6 &&
                                    DateTime.now().hour < 18
                                ? '☀️ $temperature°C, $weatherDescription'
                                : '🌌 $temperature°C, $weatherDescription')
                            : 'Fetching weather...',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16),
                      // Attendance Heading
                      const Text(
                        'Attendance',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      // Check-In and Check-Out Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatusCard('Check In', checkInTime, Icons.login,
                              Colors.green, () => _handleCheck(true)),
                          _buildStatusCard(
                              'Check Out',
                              checkOutTime,
                              Icons.logout,
                              Colors.red,
                              () => _handleCheck(false)),
                        ],
                      ),
                      // Conditionally show KPI features
                      if (_hasKpiPermission) ...[
                        const SizedBox(height: 16),
                        // KPIs Heading
                        const Text(
                          'KPIs',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        // HR KPI and Job KPI Cards
                        _buildKpiCards(),
                      ],
                      const SizedBox(height: 16),
                      // History Section with Advance Search Icon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'History',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const AdvanceSearchPage()),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      _buildHistorySection(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Embedded Camera Preview with capture button and overlay text
          if (_isCameraActive &&
              _isCameraInitialized &&
              _cameraController != null)
            Center(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                            color: const Color.fromARGB(255, 20, 20, 20),
                            width: 8.0),
                        right: BorderSide(
                            color: const Color.fromARGB(255, 15, 15, 15),
                            width: 20.0),
                      ),
                    ),
                    child: CameraPreview(_cameraController!),
                  ),
                  Positioned(
                    top: 20,
                    left: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'User: ${widget.username}',
                          style: const TextStyle(
                              color: Color.fromARGB(255, 31, 87, 33),
                              fontSize: 16),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          _isCheckIn
                              ? 'Check-In Time: ${checkInTime ?? '--:--'}'
                              : 'Check-Out Time: ${checkOutTime ?? '--:--'}',
                          style: const TextStyle(
                              color: Color.fromARGB(255, 214, 93, 12),
                              fontSize: 16),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          currentPosition != null
                              ? 'Location: ${_isCheckIn ? (checkInLocationName ?? '${currentPosition!.latitude.toStringAsFixed(5)}, ${currentPosition!.longitude.toStringAsFixed(5)}') : (checkOutLocationName ?? '${currentPosition!.latitude.toStringAsFixed(5)}, ${currentPosition!.longitude.toStringAsFixed(5)}')}'
                              : 'Location: Fetching...',
                          style: const TextStyle(
                              color: Color.fromARGB(255, 41, 1, 17),
                              fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: FloatingActionButton(
                        onPressed: _captureImage,
                        backgroundColor: Colors.blueAccent,
                        child: const Icon(Icons.camera, color: Colors.white),
                      ),
                    ),
                  ),
                  // Optional: Close camera button
                  Positioned(
                    top: 20,
                    right: 20,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _isCameraActive = false;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Function to retrieve EMP_CODE from secure storage, defaults to '00000' if not available
  Future<String> getEmpCodeForAttendance() async {
    String? empCode = await _secureStorage.read(key: 'empCodeAttendance');
    return empCode ?? '00000'; // Default to '00000' if not available
  }

  // **3. Add the Gradient-Themed Dropdown Button**
  Widget _buildThemeDropdown() {
    return DropdownButton<int>(
      value: _selectedGradientIndex,
      icon: Container(
        width: 00,
        height: 00,
        decoration: BoxDecoration(
          gradient: _gradientThemes[_selectedGradientIndex],
          shape: BoxShape.circle,
        ),
      ),
      dropdownColor: Colors.white,
      underline: Container(),
      onChanged: (int? newIndex) async {
        if (newIndex != null) {
          setState(() {
            _selectedGradientIndex = newIndex;
          });
          // Save the selected theme index to secure storage
          await _secureStorage.write(
              key: 'selectedGradientIndex', value: newIndex.toString());
          _logger.i('Selected theme index saved: $newIndex');
        }
      },
      items: List.generate(_gradientThemes.length, (index) {
        return DropdownMenuItem<int>(
          value: index,
          child: Row(
            children: [
              Container(
                width: 19,
                height: 19,
                decoration: BoxDecoration(
                  gradient: _gradientThemes[index],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 02),
            ],
          ),
        );
      }),
    );
  }
}

// Employee model class
class Employee {
  final String? id;
  final String name;

  Employee({required this.id, required this.name});

  factory Employee.fromJson(Map<String, dynamic> json) {
    String? key = json['Key'];
    String? value = json['Value'];

    // Extract employee name and EMP_CODE from 'Key' field
    String name = 'Unknown';
    String? empCode;
    if (key != null) {
      List<String> parts = key.split('--');
      if (parts.length > 1) {
        empCode = parts[0].trim(); // Extract EMP_CODE (first part)
        name = parts[1].trim(); // Extract employee name (second part)
      } else {
        name = key.trim(); // Use the whole key if no '--' separator
      }
    }

    return Employee(
      id: empCode, // Set id to EMP_CODE extracted from 'Key'
      name: name,
    );
  }
}

class KpiDialog extends StatefulWidget {
  final String kpiType;
  final String username;
  final Database? database;
  final String? userId;
  final VoidCallback onKpiMarked; // Callback to notify HomePage
  final Function(int, String, Position, bool)
      sendDataToServer; // Updated callback to include isKpi
  final Function(String, String)
      uploadImageToServer; // Callback to upload image to server with filename

  const KpiDialog({
    super.key,
    required this.kpiType,
    required this.username,
    required this.database,
    required this.userId,
    required this.onKpiMarked,
    required this.sendDataToServer,
    required this.uploadImageToServer,
  });

  @override
  _KpiDialogState createState() => _KpiDialogState();
}

class _KpiDialogState extends State<KpiDialog> {
  List<Employee> _employees = [];
  Employee? _selectedEmployee;
  bool _isLoading = true;
  bool _isCameraActive = false;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  XFile? _capturedImage;
  Position? _currentPosition; // To store current position

  // **State Variables for HR KPI**
  bool _isCheckInAction = true; // True for Check-In, False for Check-Out

  // Variables for Job Category
  String? _selectedJobCategory;
  final List<Map<String, dynamic>> _jobCategories = [
    {"Key": "ATTENDANCE", "Value": "1", "shortKey": "ATTENDANCE"},
    {"Key": "ALLIED EQUIPMENT", "Value": "10", "shortKey": "ALLIED EQUIP"},
    {
      "Key": "DUMPSITE – ENVIRONMENT FRIENDLY DISPOSAL",
      "Value": "11",
      "shortKey": "DUMPSITE DISPOSAL"
    },
    {"Key": "DUMPSITE WEIGHT", "Value": "12", "shortKey": "DUMPSITE WEIGHT"},
    {
      "Key": "CONTAINER / HAND CARTS REPAIR",
      "Value": "13",
      "shortKey": "CONTAINER REPAIR"
    },
    {
      "Key": "BULK WASTE COLLECTION BEFORE AND AFTER",
      "Value": "14",
      "shortKey": "BULK WASTE COLL"
    },
    {"Key": "TCP CLEARANCE", "Value": "15", "shortKey": "TCP CLEARANCE"},
    {"Key": "SECOND ATTENDANCE", "Value": "16", "shortKey": "SECOND ATTEND"},
    {
      "Key": "MANUAL STREET SWEEPING-COMMERCIAL",
      "Value": "2",
      "shortKey": "MANUAL SWEEP COM"
    },
    {
      "Key": "MANUAL STREET SWEEPING-RESIDENTIAL",
      "Value": "3",
      "shortKey": "MANUAL SWEEP RES"
    },
    {"Key": "MECHANICAL SWEEPING", "Value": "4", "shortKey": "MECH SWEEP"},
    {"Key": "MECHANICAL WASHING", "Value": "5", "shortKey": "MECH WASH"},
    {
      "Key": "DOOR TO DOOR COLLECTION",
      "Value": "6",
      "shortKey": "DOOR-TO-DOOR"
    },
    {
      "Key": "CONTAINERS CLEARANCE",
      "Value": "8",
      "shortKey": "CONTAINER CLRNC"
    },
    {
      "Key": "COLLECTION OF WASTE FROM COMMERCIAL AREAS",
      "Value": "9",
      "shortKey": "WASTE COLL COMM"
    },
    {"Key": "DESILTING ACTIVITIES", "Value": "7", "shortKey": "DESILTING ACT"},
  ];

  // Initialize secure storage
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Logger instance
  final Logger _logger = Logger();

  // Variables to store location name
  String? kpiLocationName;

  // **New State Variable for Marked By Username**
  String?
      _markedByUsername; // To store the username retrieved from secure storage

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _checkAndRequestLocationPermission(); // Request location permissions
    _fetchEmployees(); // Fetch employees when dialog is initialized
    _readMarkedByUsername(); // Retrieve username from secure storage
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  /// Function to read username from secure storage
  Future<void> _readMarkedByUsername() async {
    try {
      String? username = await _secureStorage.read(
          key: 'username'); // Ensure the key matches your storage
      if (username != null) {
        setState(() {
          _markedByUsername = username;
        });
        _logger.i('Username retrieved from secure storage: $username');
      } else {
        _logger.e('Username not found in secure storage.');
        _showError('User information not available.');
      }
    } catch (e) {
      _logger.e('Error reading username from secure storage: $e');
      _showError('Failed to retrieve user information.');
    }
  }

  /// Initializes the camera
  Future<void> _initializeCamera() async {
    if (widget.database == null || widget.userId == null) {
      _showError('Database or User ID not available.');
      return;
    }

    // Request camera permission if not already granted
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
      if (!status.isGranted) {
        _showError('Camera permission denied');
        return;
      }
    }

    // Get available cameras
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      _showError('No cameras available');
      return;
    }

    final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first);

    _cameraController = CameraController(
      backCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
      });
      _logger.i('Camera initialized successfully in KPI Dialog.');
    } catch (e) {
      _showError('Failed to initialize camera: $e');
    }
  }

  /// Checks and requests location permissions
  Future<void> _checkAndRequestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError('Location services are disabled.');
      return;
    }

    // Check for location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Request permission
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError('Location permissions are denied.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately
      _showError(
          'Location permissions are permanently denied, we cannot request permissions.');
      return;
    }

    // When permissions are granted, get the position
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = position;
      });
      _logger
          .i('Location obtained: ${position.latitude}, ${position.longitude}');
      // Optionally, perform reverse geocoding to get location name
      await _setLocationName(position.latitude, position.longitude);
    } catch (e) {
      _showError('Error obtaining location: $e');
    }
  }

  /// Sets the human-readable location name using reverse geocoding
  Future<void> _setLocationName(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        String locationName =
            '${placemark.subThoroughfare ?? ''} ${placemark.thoroughfare ?? ''}, '
            '${placemark.subLocality ?? ''}, '
            '${placemark.locality ?? ''}, '
            '${placemark.administrativeArea ?? ''}, '
            '${placemark.postalCode ?? ''}, '
            '${placemark.country ?? ''}';
        setState(() {
          kpiLocationName = locationName;
        });
      }
    } catch (e) {
      _logger.e('Error in reverse geocoding: $e');
      setState(() {
        kpiLocationName = 'Unknown Location';
      });
    }
  }

  /// Fetches employees from the API based on KPI type and action
  Future<void> _fetchEmployees() async {
    setState(() {
      _isLoading = true;
    });
    try {
      String? empId = await getEmpId();
      String? accessToken = await getAccessToken();
      if (empId == null || accessToken == null) {
        _showError('Employee ID or access token not found.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      String baseUrl = ApiService.getBaseUrl(); // Dynamically fetch base URL
      String apiEndpoint;

      if (widget.kpiType == 'HR') {
        // Determine which API to call based on selected action
        apiEndpoint = _isCheckInAction
            ? 'api/GENDropDown/GetNotCheckedInEmployees?Id=$empId'
            : 'api/GENDropDown/GetEmployeesbyReportsTo?Id=$empId';
      } else {
        // Existing API for Job KPI
        apiEndpoint = 'api/GENDropDown/GetEmployeesbyReportsTo?Id=$empId';
      }

      final url = '$baseUrl$apiEndpoint';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _logger.i('API Response Data: $data'); // For debugging
        setState(() {
          _employees = data
              .map((json) => Employee.fromJson(json))
              // ignore: unnecessary_null_comparison
              .where((employee) => employee.name != null)
              .toList();
          _isLoading = false;
        });
      } else {
        _showError('Failed to load employees: ${response.statusCode}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _showError('Error fetching employees: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String?> getEmpId() async {
    return await _secureStorage.read(key: 'empId');
  }

  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: 'accessToken');
  }

  // **Function to retrieve EMP_CODE for Attendance**
  Future<String> getEmpCodeForAttendance() async {
    String? empCode = await _secureStorage.read(key: 'empCodeKpi');
    return empCode ?? '00000'; // Default to '00000' if not available
  }

  /// Displays an error message using SnackBar
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

  /// Displays a success message using SnackBar
  void _showSuccess(String message) {
    _logger.i('Showing success SnackBar: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
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

  /// Builds the employee dropdown menu
  Widget _buildEmployeeDropdown() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (_employees.isEmpty) {
      return const Text('No employees found.');
    } else {
      return DropdownButtonFormField<Employee>(
        isExpanded: true, // Ensures the dropdown takes up available width
        decoration: const InputDecoration(
          labelText: 'Select Employee',
          border: OutlineInputBorder(),
        ),
        value: _selectedEmployee,
        items: _employees.map((employee) {
          return DropdownMenuItem<Employee>(
            value: employee,
            child: Text(
              employee.name,
              overflow: TextOverflow.ellipsis, // Prevent overflow
            ),
          );
        }).toList(),
        onChanged: (Employee? value) {
          setState(() {
            _selectedEmployee = value;
            if (widget.kpiType == 'HR') {
              _secureStorage.write(key: 'empCodeKpi', value: value?.id);
            }
            if (widget.kpiType == 'Job') {
              _secureStorage.write(
                  key: 'selectedJobKpiType', value: _getJobKpiTypeValue());
            }
          });
        },
      );
    }
  }

  /// Retrieves the job KPI type value based on selected employee
  String _getJobKpiTypeValue() {
    if (_selectedEmployee == null) {
      return "0";
    }
    // Find the corresponding value from _jobCategories based on employee selection
    for (var category in _jobCategories) {
      if (category['Value'] == _selectedEmployee!.id) {
        return category['Value'];
      }
    }
    return "0"; // Default value
  }

  /// Builds the job category dropdown with shortened names
  Widget _buildJobCategoryDropdown() {
    return DropdownButtonFormField<String>(
      isExpanded: true, // Ensures the dropdown takes up available width
      decoration: const InputDecoration(
        labelText: 'Job Category',
        border: OutlineInputBorder(),
      ),
      value: _selectedJobCategory,
      items: _jobCategories.map((category) {
        return DropdownMenuItem<String>(
          value: category['Value'],
          child: Text(
            category['shortKey'],
            overflow: TextOverflow.ellipsis, // Prevents text overflow
            maxLines: 1, // Ensures single-line display
          ),
        );
      }).toList(),
      onChanged: (String? value) {
        setState(() {
          _selectedJobCategory = value;
          _secureStorage.write(key: 'selectedJobKpiType', value: value);
        });
      },
    );
  }

  /// Retrieves the job category text based on selected value
  String _getJobCategoryText() {
    for (var category in _jobCategories) {
      if (category['Value'] == _selectedJobCategory) {
        return category['shortKey']
            .toString()
            .replaceAll(RegExp(r'\r\n|\n'), '')
            .trim();
      }
    }
    return 'Uncategorized';
  }

  /// Handles the KPI submission process
  void _submitKpi() async {
    if (_selectedEmployee == null) {
      _showError('Please select an employee.');
      return;
    }

    if (widget.kpiType == 'Job' && _selectedJobCategory == null) {
      _showError('Please select a job category.');
      return;
    }

    if (_capturedImage == null) {
      _showError('Please capture a picture.');
      return;
    }

    if (widget.kpiType == 'HR' && _isCheckInAction == null) {
      _showError('Please select Check-In or Check-Out.');
      return;
    }

    if (_currentPosition == null) {
      _showError('Location is not available.');
      return;
    }

    if (_markedByUsername == null) {
      _showError('User information is missing.');
      return;
    }

    try {
      // Prepare the overlay text with additional details including 'markedBy'
      String overlayText =
          'Employee: ${_selectedEmployee?.name ?? 'No employee selected'}\n'
          'Time: ${DateFormat('yyyy-MM-dd hh:mm a').format(DateTime.now())}\n'
          'Street Address: ${kpiLocationName ?? 'Unknown'}\n'
          'Coordinates: ${_currentPosition?.latitude.toStringAsFixed(5)}, ${_currentPosition?.longitude.toStringAsFixed(5)}\n'
          'Marked By: ${widget.username}';

      // Include Job Category if KPI type is 'Job'
      if (widget.kpiType == 'Job' && _selectedJobCategory != null) {
        overlayText += '\nJob Category: ${_getJobCategoryText()}';
      }

      // Insert KPI record into the database
      await widget.database!.insert(
        'kpi',
        {
          'user_id': widget.userId,
          'username': widget.username,
          'kpi_type': widget.kpiType,
          'kpi_time': DateFormat('yyyy-MM-dd – kk:mm').format(DateTime.now()),
          'employee_name': _selectedEmployee?.name ?? 'Unknown',
          'image_path': _capturedImage!.path,
          if (widget.kpiType == 'Job')
            'job_category': _selectedJobCategory ?? 'Uncategorized',
          if (widget.kpiType == 'HR')
            'submission_type':
                _isCheckInAction ? 1 : 2, // 1 for Check-In, 2 for Check-Out
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _showSuccess(
          '${widget.kpiType} KPI marked successfully for ${_selectedEmployee?.name}!');

      // Determine the type based on KPIType and submissionType
      int type;
      if (widget.kpiType == 'HR') {
        type = _isCheckInAction ? 1 : 2; // 1 for Check-In, 2 for Check-Out
      } else {
        type = 5; // Job KPI
      }

      // **Assign filename based on employee code and KPI type**
      String filename =
          '${_selectedEmployee?.id ?? '00000'}_${widget.kpiType.toLowerCase()}_kpi_pic.jpg';

      // Retrieve EMP_CODE from secure storage
      String empCode = await getEmpCodeForAttendance();

      // Upload the image to the server in background with the assigned filename
      widget.uploadImageToServer(_capturedImage!.path, filename);

      // Send data to server with type and isKpi flag
      await widget.sendDataToServer(
        type,
        _capturedImage!.path,
        _currentPosition!,
        widget.kpiType == 'HR', // True for HR KPI, false otherwise
      );

      // Notify HomePage to refresh History
      widget.onKpiMarked();

      // Close the dialog
      Navigator.of(context).pop();
    } catch (e) {
      _showError('Failed to submit KPI: $e');
    }
  }

  /// Overlays text onto the captured image
  Future<void> _overlayTextOnImage(String imagePath, String text) async {
    try {
      // Load the image as bytes
      File imageFile = File(imagePath);
      Uint8List imageBytes = await imageFile.readAsBytes();

      ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
      ui.FrameInfo frameInfo = await codec.getNextFrame();
      ui.Image originalImage = frameInfo.image;

      // Create a canvas to draw on
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Draw the original image onto the canvas
      canvas.drawImage(originalImage, Offset.zero, Paint());

      // Define padding around text
      const double padding = 8.0;

      // Prepare the text style with orange color
      final textStyle = ui.TextStyle(
        color: Colors.orange, // Orange text
        fontSize: 24,
        shadows: [
          ui.Shadow(
            offset: const Offset(2.0, 2.0),
            blurRadius: 3.0,
            color: Colors.black,
          ),
        ],
      );

      // Prepare the paragraph style
      final paragraphStyle = ui.ParagraphStyle(
        textDirection: ui.TextDirection.ltr,
      );

      // Build the paragraph with the text
      final paragraphBuilder = ui.ParagraphBuilder(paragraphStyle)
        ..pushStyle(textStyle)
        ..addText(text);

      final paragraph = paragraphBuilder.build()
        ..layout(ui.ParagraphConstraints(
            width: originalImage.width.toDouble() - 20));

      // Calculate background rectangle size
      final Rect backgroundRect = Rect.fromLTWH(
        10,
        10,
        paragraph.width + padding * 2,
        paragraph.height + padding * 2,
      );

      // Draw semi-transparent black rectangle as background
      final Paint backgroundPaint = Paint()
        ..color = Colors.black.withOpacity(0.5);
      canvas.drawRect(backgroundRect, backgroundPaint);

      // Draw the text onto the canvas
      canvas.drawParagraph(paragraph, Offset(10 + padding, 10 + padding));

      // End recording and get the new image
      final picture = recorder.endRecording();
      final newImage =
          await picture.toImage(originalImage.width, originalImage.height);
      final pngBytes =
          await newImage.toByteData(format: ui.ImageByteFormat.png);

      // Save the image to the file
      await imageFile.writeAsBytes(pngBytes!.buffer.asUint8List());
    } catch (e) {
      _logger.e('Error overlaying text on image: $e');
    }
  }

  /// Function to save the captured image locally and return the new path
  Future<String> _saveImageLocally(XFile image) async {
    final directory = await getApplicationDocumentsDirectory();
    final String path = directory.path;
    final String fileName = 'kpi_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final File newImage = await File(image.path).copy('$path/$fileName');
    return newImage.path;
  }

  /// Handles the image capture process based on KPI type
  Future<void> _captureImageKpi() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _showError('Camera is not initialized.');
      return;
    }

    if (_currentPosition == null) {
      _showError('Location is not available.');
      return;
    }

    if (_markedByUsername == null) {
      _showError('User information is missing.');
      return;
    }

    try {
      // Capture the image
      XFile image = await _cameraController!.takePicture();
      _logger.i('Image captured at: ${image.path}');

      // Save the image locally and get the new path
      String localImagePath = await _saveImageLocally(image);
      _logger.i('Image saved locally at: $localImagePath');

      // Close the camera preview
      setState(() {
        _isCameraActive = false;
        _capturedImage = XFile(localImagePath); // Update captured image
      });

      // Prepare the overlay text with additional details including 'markedBy'
      String overlayText =
          'Employee: ${_selectedEmployee?.name ?? 'No employee selected'}\n'
          'Time: ${DateFormat('yyyy-MM-dd hh:mm a').format(DateTime.now())}\n'
          'Street Address: ${kpiLocationName ?? 'Unknown'}\n'
          'Coordinates: ${_currentPosition?.latitude.toStringAsFixed(5)}, ${_currentPosition?.longitude.toStringAsFixed(5)}\n'
          'Marked By: ${widget.username}';

      // Include Job Category if KPI type is 'Job'
      if (widget.kpiType == 'Job' && _selectedJobCategory != null) {
        overlayText += '\nJob Category: ${_getJobCategoryText()}';
      }

      // Overlay text onto the image
      await _overlayTextOnImage(localImagePath, overlayText);

      // **Do NOT Insert into Database or Upload Here**
      // All insertion and uploading are handled in _submitKpi()
    } catch (e) {
      _logger.e('Error capturing image: $e');
      _showError('Failed to capture image.');
      setState(() {
        _isCameraActive = false; // Ensure camera is closed on error
      });
    }
  }

  /// Fetches the source value required for the image upload API
  Future<String> getSource() async {
    // Implement this function based on your requirements
    // It should return the appropriate source value required for the image upload API
    return "app"; // Placeholder value
  }

  /// Determines if the current submission is a Job KPI
  bool _isJobKpiSubmission() {
    return widget.kpiType == 'Job';
  }

  /// Uploads the image to the server
  Future<void> _uploadImageToServer(String imagePath, String filename) async {
    String baseUrl = ApiService.getBaseUrl();

    String apiUrl = '${baseUrl}api/GenNotifications/uploadimageupdated';
    String? accessToken = await getAccessToken();

    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.headers['Authorization'] = 'Bearer $accessToken';

      // Assign the desired filename based on the action
      request.files.add(await http.MultipartFile.fromPath(
        'avatar',
        imagePath,
        filename: filename,
      ));

      // Add EMP_CODE, ATTENDANCE_TYPE, and Source fields
      String empCode = await getEmpCodeForAttendance();
      int attendanceType;
      if (widget.kpiType == 'HR') {
        attendanceType =
            _isCheckInAction ? 1 : 2; // 1 for Check-In, 2 for Check-Out
      } else {
        attendanceType = 5; // 5 for Job KPI
      }
      String source = await getSource();

      request.fields['EMP_CODE'] = empCode;
      request.fields['ATTENDANCE_TYPE'] = attendanceType.toString();
      request.fields['Source'] = source;
      // Added KPI_TYPE
      request.fields['KPI_TYPE'] = widget.kpiType == 'HR'
          ? "1"
          : widget.kpiType == 'Job'
              ? "2"
              : "0";

      var response = await request.send();

      // Parse and print the JSON response
      final responseBody = await response.stream.bytesToString();
      if (responseBody.isNotEmpty) {
        final responseJson = json.decode(responseBody);
        _logger.i('Image Upload Response: $responseJson');
      } else {
        _logger.w('Image Upload Response Body is empty.');
      }

      if (response.statusCode == 200) {
        _logger.i('Image successfully saved to server');
      } else {
        _logger.e('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Error uploading image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9, // 90% of screen width
          child: _isCameraActive &&
                  _isCameraInitialized &&
                  _cameraController != null
              ? Stack(
                  children: [
                    CameraPreview(_cameraController!),
                    Positioned(
                      top: 20,
                      left: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.kpiType} KPI Marking for ${_selectedEmployee?.name ?? 'Employee'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              backgroundColor: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 40,
                      left: MediaQuery.of(context).size.width / 2 - 30,
                      child: FloatingActionButton(
                        onPressed: _captureImageKpi,
                        backgroundColor: Colors.blueAccent,
                        child: const Icon(Icons.camera, color: Colors.white),
                      ),
                    ),
                    // Optional: Close camera button
                    Positioned(
                      top: 20,
                      right: 20,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _isCameraActive = false;
                          });
                        },
                      ),
                    ),
                  ],
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.kpiType == 'HR') ...[
                          // **Updated Check-In and Check-Out Buttons with Icons and Modern Styling**
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Check-In Button
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _isCheckInAction = true;
                                    _selectedEmployee = null;
                                    _selectedJobCategory = null;
                                    _capturedImage = null;
                                  });
                                  _fetchEmployees();
                                },
                                icon: Icon(
                                  Icons.login, // Icon for Check-In
                                  color: Colors.white,
                                ),
                                label: Text(
                                  'Check-In',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isCheckInAction
                                      ? Colors.green
                                      : const Color.fromARGB(
                                          255, 177, 168, 168),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30.0),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 20.0, vertical: 12.0),
                                  elevation: _isCheckInAction
                                      ? 8
                                      : 2, // Dynamic elevation
                                ),
                              ),
                              SizedBox(
                                  width:
                                      20.0), // Increased spacing for better separation
                              // Check-Out Button
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _isCheckInAction = false;
                                    _selectedEmployee = null;
                                    _selectedJobCategory = null;
                                    _capturedImage = null;
                                  });
                                  _fetchEmployees();
                                },
                                icon: Icon(
                                  Icons.logout, // Icon for Check-Out
                                  color: Colors.white,
                                ),
                                label: Text(
                                  'Check-Out',
                                  style: TextStyle(
                                    color: const Color.fromARGB(255, 104, 6, 6),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: !_isCheckInAction
                                      ? Colors.red
                                      : const Color.fromARGB(
                                          255, 174, 147, 147),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30.0),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 20.0, vertical: 12.0),
                                  elevation: !_isCheckInAction
                                      ? 8
                                      : 2, // Dynamic elevation
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16.0),
                        ],
                        Text(
                          '${widget.kpiType} KPI',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        // **Conditional Rendering Based on KPI Type and Action**
                        if (widget.kpiType == 'HR') ...[
                          _buildEmployeeDropdown(),
                          const SizedBox(height: 16.0),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _startCameraKpi,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Take Picture'),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30.0),
                                ),
                                backgroundColor:
                                    const Color.fromARGB(255, 54, 190, 104),
                                elevation: 5,
                              ),
                            ),
                          ),
                        ] else if (widget.kpiType == 'Job') ...[
                          _buildEmployeeDropdown(),
                          const SizedBox(height: 16.0),
                          _buildJobCategoryDropdown(),
                          const SizedBox(height: 16.0),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _startCameraKpi,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Take Picture'),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30.0),
                                ),
                                backgroundColor:
                                    const Color.fromARGB(255, 54, 190, 104),
                                elevation: 5,
                              ),
                            ),
                          ),
                        ],
                        // **Show Captured Image Preview and Submit Button**
                        if (_capturedImage != null) ...[
                          const SizedBox(height: 16.0),
                          Text(
                            'Picture Captured:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8.0),
                          // Display captured image with overlay text
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.file(
                                  File(_capturedImage!.path),
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                left: 8,
                                right: 8,
                                child: Container(
                                  color: Colors.black54,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 4.0, horizontal: 8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Employee: ${_selectedEmployee?.name ?? 'No employee selected'}',
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 12),
                                      ),
                                      Text(
                                        '${widget.kpiType} KPI Submitted on ${DateFormat('yyyy-MM-dd – kk:mm').format(DateTime.now())}',
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 12),
                                      ),
                                      if (widget.kpiType == 'Job' &&
                                          _selectedJobCategory != null)
                                        Text(
                                          'Job Category: ${_getJobCategoryText()}',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12),
                                        ),
                                      // **Optional: Display 'Marked By'**
                                      Text(
                                        'Marked By: ${_markedByUsername ?? 'Unknown'}',
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16.0),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _submitKpi,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30.0),
                                ),
                                elevation: 5,
                              ),
                              child: const Text('Submit'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
        ));
  }

  /// Starts the camera for KPI submission
  void _startCameraKpi() {
    setState(() {
      _isCameraActive = true;
    });
  }
}
