// login.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'homepage.dart'; // Ensure you have HomePage implemented
import 'package:logger/logger.dart'; // Optional: For advanced logging
import 'package:cached_network_image/cached_network_image.dart';
import 'api_service.dart'; // Import ApiService class
import 'package:uuid/uuid.dart'; // Added for generating UUIDs

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controllers for input fields
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Secure storage instance
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Local Authentication instance
  final LocalAuthentication _auth = LocalAuthentication();

  // Logger instance (optional)
  final Logger _logger = Logger();

  // Uuid instance for generating session IDs
  final Uuid _uuid = const Uuid();

  // Form key for validation
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // State variables
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isButtonPressed = false;
  bool _biometricsEnabled = false; // Tracks if biometrics are enabled

  // Define the company info endpoint with the dynamic base URL
  String get _companyInfoEndpoint {
    return '${ApiService.getBaseUrl()}/api/Account/CompanyInfo?LicenceAcountId=1&CompanyId=1';
  }

  // State variables for company data
  String _companyName = 'Loading...';
  String _companyLogoUrl = '';

  // Track loading state for company data
  bool _isCompanyDataLoading = true;
  String? _companyDataError;

  @override
  void initState() {
    super.initState();
    _checkBiometricsEnabled(); // Check if biometrics are enabled on startup
    _fetchCompanyData(); // Fetch company data on startup
  }

  @override
  void dispose() {
    // Dispose controllers to free resources
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Fetches company data from the API
  Future<void> _fetchCompanyData() async {
    setState(() {
      _isCompanyDataLoading = true;
      _companyDataError = null;
    });

    try {
      // ignore: unused_local_variable
      final String baseUrl = ApiService.getBaseUrl();
      final Uri url = Uri.parse(_companyInfoEndpoint);

      _logger.d('Fetching company data from $url');

      final http.Response response =
          await http.get(url).timeout(const Duration(seconds: 15));

      _logger.d('Company data response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        _logger.d('Company data: $data');

        setState(() {
          _companyName = data['CO_NAME'] ?? 'Company Name';

          // Construct the full image URL using the dynamic base URL
          _companyLogoUrl = data['COMPANY_LOGO'] != null &&
                  data['COMPANY_LOGO'].toString().isNotEmpty
              ? '${ApiService.getBaseUrl()}${data['COMPANY_LOGO']}'
              : '';

          _isCompanyDataLoading = false;
        });
      } else {
        _logger.e('Failed to fetch company data: ${response.body}');
        setState(() {
          _companyDataError = 'Failed to load company information.';
          _isCompanyDataLoading = false;
        });
      }
    } catch (e) {
      _logger.e('Error fetching company data: $e');
      setState(() {
        _companyDataError =
            'An error occurred while fetching company information.';
        _isCompanyDataLoading = false;
      });
    }
  }

  /// Checks if biometric authentication is enabled and attempts authentication if so.
  Future<void> _checkBiometricsEnabled() async {
    _logger.d('Checking if biometrics are enabled.');
    String? biometrics = await _secureStorage.read(key: 'biometricsEnabled');
    setState(() {
      _biometricsEnabled = biometrics == 'true';
    });

    if (_biometricsEnabled) {
      _logger.d('Biometrics are enabled. Attempting authentication.');
      _authenticateWithBiometrics();
    }
  }

  /// Handles biometric authentication process.
  Future<void> _authenticateWithBiometrics() async {
    _logger.d('Starting biometric authentication.');
    bool canCheckBiometrics = await _auth.canCheckBiometrics;
    bool isDeviceSupported = await _auth.isDeviceSupported();
    bool isAuthenticated = false;

    _logger.d('Can check biometrics: $canCheckBiometrics');
    _logger.d('Is device supported: $isDeviceSupported');

    if (canCheckBiometrics && isDeviceSupported) {
      try {
        isAuthenticated = await _auth.authenticate(
          localizedReason: 'Please authenticate to log in',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );
        _logger.d('Authentication result: $isAuthenticated');
      } catch (e) {
        _showErrorSnackBar('Biometric authentication failed.');
        _logger.e('Biometric auth error: $e');
        return;
      }

      if (isAuthenticated) {
        // Retrieve stored credentials
        String? personName = await _secureStorage.read(key: 'personName');
        String? userId = await _secureStorage.read(key: 'userId');
        String? accessToken = await _secureStorage.read(key: 'accessToken');
        String? empId = await _secureStorage.read(key: 'empId');
        // ignore: unused_local_variable
        String? userName = await _secureStorage.read(key: 'username');

        _logger.d('Retrieved credentials from storage: '
            'PersonName: $personName, UserID: $userId, AccessToken: $accessToken, EmpID: $empId');

        if (personName != null &&
            userId != null &&
            accessToken != null &&
            empId != null) {
          // **Modified Navigation: Pass personName as username**
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomePage(username: personName),
            ),
          );
        } else {
          _showErrorSnackBar('No stored credentials found.');
          _logger.e('No stored credentials found.');
        }
      } else {
        _showErrorSnackBar('Authentication failed.');
        _logger.e('Biometric authentication failed.');
      }
    } else {
      _showErrorSnackBar('Biometric authentication is not available.');
      _logger.e('Biometric authentication not available.');
    }
  }

  /// Toggles the visibility of the password field.
  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  /// Handles the login process.
  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      _logger.d('Attempting to log in.');

      final String username = _usernameController.text.trim();
      final String password = _passwordController.text.trim();

      if (username.isNotEmpty && password.isNotEmpty) {
        try {
          // Access baseUrl via ApiService
          String baseUrl = ApiService.getBaseUrl();
          var url = Uri.parse(
              '$baseUrl/Token'); // Append the endpoint to the base URL
          _logger.d('Sending POST request to $url');

          var response = await http.post(
            url,
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {
              'grant_type': 'password',
              'username': username,
              'password': password,
              'companyid': '1',
            },
          ).timeout(const Duration(seconds: 30));

          _logger.d('Received response: ${response.statusCode}');

          if (response.statusCode == 200) {
            var data = json.decode(response.body);
            _logger.d('Login response data: $data');

            // Extract required fields from response
            String userId = data['userId']?.toString() ?? '';
            String accessToken = data['access_token']?.toString() ?? '';
            String empId = data['empId']?.toString() ?? '';
            String personName =
                data['personName']?.toString() ?? ''; // **New Field**
            String permissionsJsonString =
                data['permissions']?.toString() ?? '';

            _logger.d(
                'Permissions JSON string from response: $permissionsJsonString');

            List<dynamic>? permissionsList;

            if (permissionsJsonString.isNotEmpty) {
              // Decode the permissions JSON string to a List
              try {
                permissionsList = json.decode(permissionsJsonString);
                _logger.d('Decoded permissions: $permissionsList');
              } catch (e) {
                _logger.e('Error decoding permissions JSON string: $e');
                permissionsList = null;
              }
            }

            // Store credentials securely
            await _secureStorage.write(key: 'userId', value: userId);
            await _secureStorage.write(key: 'accessToken', value: accessToken);
            await _secureStorage.write(key: 'empId', value: empId);
            await _secureStorage.write(key: 'username', value: username);
            // Removed storing password for enhanced security
            await _secureStorage.write(
                key: 'personName', value: personName); // **Store personName**
            // Store permissions if available
            if (permissionsList != null) {
              String permissionsJson = json.encode(permissionsList);
              await _secureStorage.write(
                  key: 'permissions', value: permissionsJson);
              _logger.d('Permissions stored in secure storage.');
            } else {
              _logger.w('No permissions found to store.');
            }

            // **New Code: Add Login History**
            await _addLoginHistory(username, accessToken);

            // Prompt user to enable biometric authentication
            bool canCheckBiometrics = await _auth.canCheckBiometrics;
            bool isDeviceSupported = await _auth.isDeviceSupported();
            bool biometricsAvailable = canCheckBiometrics && isDeviceSupported;

            _logger.d('Can check biometrics: $canCheckBiometrics');
            _logger.d('Is device supported: $isDeviceSupported');

            if (biometricsAvailable) {
              bool enableBiometrics = await _showBiometricPrompt();

              if (enableBiometrics) {
                // Authenticate before enabling biometrics
                bool authenticated = await _auth.authenticate(
                  localizedReason:
                      'Please authenticate to enable biometric login',
                  options: const AuthenticationOptions(
                    biometricOnly: true,
                    stickyAuth: true,
                  ),
                );

                if (authenticated) {
                  await _secureStorage.write(
                      key: 'biometricsEnabled', value: 'true');
                  setState(() {
                    _biometricsEnabled = true;
                  });
                  _showInfoSnackBar('Biometric authentication enabled.');
                  _logger.d('Biometric authentication enabled.');
                } else {
                  _showErrorSnackBar('Biometric authentication failed.');
                  _logger.e('Biometric authentication failed during enabling.');
                }
              }
            }

            // **Modified Navigation: Pass personName as username**
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomePage(username: personName),
              ),
            );
          } else {
            // Handle error responses
            String errorMessage = 'Invalid username or password!';
            try {
              var errorData = json.decode(response.body);
              if (errorData['error_description'] != null) {
                errorMessage = errorData['error_description'];
              }
            } catch (_) {}
            _showErrorSnackBar(errorMessage);
            _logger.e('Login failed: $errorMessage');
          }
        } catch (e) {
          _showErrorSnackBar('An error occurred. Please try again.');
          _logger.e('Login error: $e');
        }
      } else {
        _showErrorSnackBar('Please enter both username and password!');
        _logger.e('Username or password is empty.');
      }

      setState(() => _isLoading = false);
    }
  }

  /// Fetches the user's public IP address using the ipify API
  Future<String> _getRemoteIP() async {
    try {
      final Uri ipUrl = Uri.parse('https://api.ipify.org?format=json');
      final http.Response ipResponse =
          await http.get(ipUrl).timeout(const Duration(seconds: 10));

      if (ipResponse.statusCode == 200) {
        final Map<String, dynamic> ipData = json.decode(ipResponse.body);
        String ip = ipData['ip'] ?? '0.0.0.0';
        _logger.d('Fetched remote IP: $ip');
        return ip;
      } else {
        _logger.e('Failed to fetch IP. Status code: ${ipResponse.statusCode}');
        return '0.0.0.0';
      }
    } catch (e) {
      _logger.e('Error fetching remote IP: $e');
      return '0.0.0.0';
    }
  }

  /// Adds a login history record by calling the AddLoginHistory API
  Future<void> _addLoginHistory(String username, String accessToken) async {
    _logger.d('Adding login history for user: $username');

    // Generate a unique session ID
    String sessionId = _uuid.v4();
    _logger.d('Generated session ID: $sessionId');

    // Fetch the remote IP
    String remoteIP = await _getRemoteIP();

    // Prepare the login history data
    Map<String, dynamic> loginHistory = {
      "LIC_ACC_ID": 1,
      "CO_ID": 1,
      "LOGIN_HISTORY_ID": 0, // the backend auto-generates this
      "USER_NAME": username,
      "REMOTE_IP": remoteIP,
      "IS_SUCCESS": true,
      "SESSION_ID": sessionId,
      "LOGOFF_TIME": DateTime.now().toIso8601String(),
    };

    String loginHistoryUrl =
        '${ApiService.getBaseUrl()}/api/LoginHistory/AddLoginHistory';

    _logger.d('Sending login history POST request to $loginHistoryUrl');
    _logger.d('Login history data: $loginHistory');

    try {
      final http.Response historyResponse = await http
          .post(
            Uri.parse(loginHistoryUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken', // Added access token
            },
            body: json.encode(loginHistory),
          )
          .timeout(const Duration(seconds: 15));

      _logger.d('Login history response status: ${historyResponse.statusCode}');
      _logger.d('Login history response body: ${historyResponse.body}');

      if (historyResponse.statusCode == 200 ||
          historyResponse.statusCode == 201) {
        _logger.d('Login history recorded successfully.');
      } else {
        _logger.e('Failed to record login history: ${historyResponse.body}');
      }
    } catch (e) {
      _logger.e('Error recording login history: $e');
    }
  }

  /// Displays a dialog prompting the user to enable biometric authentication.
  Future<bool> _showBiometricPrompt() async {
    _logger.d('Showing biometric enable prompt.');
    bool? enable = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enable Biometric Login'),
          content: const Text(
              'Would you like to enable fingerprint authentication for future logins?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    _logger.d('Biometric prompt result: $enable');
    return enable ?? false;
  }

  /// Authenticates the user when toggling biometrics on/off.
  Future<bool> _authenticateBiometricToggle() async {
    _logger.d('Authenticating for biometric toggle.');
    bool canCheckBiometrics = await _auth.canCheckBiometrics;
    bool isDeviceSupported = await _auth.isDeviceSupported();
    bool isAuthenticated = false;

    _logger.d('Can check biometrics: $canCheckBiometrics');
    _logger.d('Is device supported: $isDeviceSupported');

    if (canCheckBiometrics && isDeviceSupported) {
      try {
        isAuthenticated = await _auth.authenticate(
          localizedReason:
              'Please authenticate to ${_biometricsEnabled ? 'disable' : 'enable'} fingerprint login',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );
        _logger.d('Authentication result for toggle: $isAuthenticated');
      } catch (e) {
        _showErrorSnackBar('Biometric authentication failed.');
        _logger.e('Biometric toggle auth error: $e');
        return false;
      }
    } else {
      _showErrorSnackBar('Biometric authentication is not available.');
      _logger.e('Biometric authentication not available for toggle.');
      return false;
    }

    return isAuthenticated;
  }

  /// Displays an error SnackBar with the provided message.
  void _showErrorSnackBar(String message) {
    _logger.d('Showing error SnackBar: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  /// Displays an informational SnackBar with the provided message.
  void _showInfoSnackBar(String message) {
    _logger.d('Showing info SnackBar: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildCompanyLogo() {
    if (_isCompanyDataLoading) {
      return Container(
        width: 150, // Increased size to avoid clipping
        height: 150, // Increased size to avoid clipping
        alignment: Alignment.center,
        child: const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
        ),
      );
    } else if (_companyDataError != null) {
      return Container(
        width: 150, // Increased size to avoid clipping
        height: 150, // Increased size to avoid clipping
        alignment: Alignment.center,
        child: const Icon(
          Icons.error,
          size: 80, // Slightly smaller icon to fit within the circle
          color: Colors.redAccent,
        ),
      );
    } else if (_companyLogoUrl.isEmpty) {
      // Handle cases where the logo URL is empty
      return Container(
        width: 120, // Increased size to avoid clipping
        height: 120, // Increased size to avoid clipping
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color.fromARGB(
              255, 8, 0, 0), // Background color for missing logo
        ),
        child: const Icon(
          Icons.business,
          size: 90, // Slightly smaller icon to fit within the circle
          color: Colors.white,
        ),
      );
    } else {
      return Container(
        width: 120, // Increased size to avoid clipping
        height: 120, // Increased size to avoid clipping
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 5,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: _companyLogoUrl,
            placeholder: (context, url) => const CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 0, 0, 0)),
            ),
            errorWidget: (context, url, error) => const Icon(
              Icons.error,
              size: 90, // Slightly smaller icon to fit within the circle
              color: Colors.redAccent,
            ),
            fit: BoxFit.contain, // Ensures the logo doesn't get clipped
            width: 120, // Match container size
            height: 120, // Match container size
          ),
        ),
      );
    }
  }

  /// Builds the company name text widget.
  Widget _buildCompanyNameText() {
    if (_isCompanyDataLoading) {
      return const Text(
        'Loading...',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white70,
        ),
      );
    } else if (_companyDataError != null) {
      return const Text(
        'Company Name',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white70,
        ),
      );
    } else {
      return Text(
        _companyName,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white70,
        ),
      );
    }
  }

  /// Builds a customizable text field widget with validation.
  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        prefixIcon: Icon(icon, color: Colors.white),
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Colors.lightBlueAccent),
        ),
        errorStyle: const TextStyle(color: Colors.yellowAccent),
      ),
    );
  }

  /// Builds the biometric toggle switch widget.
  Widget _buildBiometricToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Enable Fingerprint Login',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 16,
          ),
        ),
        // Enhanced accessibility using Semantics widget
        Semantics(
          label: _biometricsEnabled
              ? 'Disable Fingerprint Login'
              : 'Enable Fingerprint Login',
          child: Switch(
            value: _biometricsEnabled,
            onChanged: (bool value) async {
              _logger.d('Biometric toggle switched to: $value');
              if (value) {
                // Attempt to authenticate before enabling biometrics
                bool authenticated = await _authenticateBiometricToggle();
                if (authenticated) {
                  // Store biometric preference
                  await _secureStorage.write(
                      key: 'biometricsEnabled', value: 'true');
                  setState(() {
                    _biometricsEnabled = true;
                  });
                  _showInfoSnackBar('Biometric authentication enabled.');
                  _logger.d('Biometric authentication enabled.');
                } else {
                  _showErrorSnackBar('Biometric authentication failed.');
                  _logger.e('Biometric authentication failed during toggle.');
                }
              } else {
                // Attempt to authenticate before disabling biometrics
                bool authenticated = await _authenticateBiometricToggle();
                if (authenticated) {
                  await _secureStorage.write(
                      key: 'biometricsEnabled', value: 'false');
                  setState(() {
                    _biometricsEnabled = false;
                  });
                  _showInfoSnackBar('Biometric authentication disabled.');
                  _logger.d('Biometric authentication disabled.');
                } else {
                  _showErrorSnackBar('Biometric authentication failed.');
                  _logger.e('Biometric authentication failed during toggle.');
                }
              }
            },
            activeColor: Colors.greenAccent,
            inactiveThumbColor: Colors.grey,
          ),
        ),
      ],
    );
  }

  /// Builds the login button with animations.
  Widget _buildLoginButton() {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isButtonPressed = true),
      onTapUp: (_) => setState(() => _isButtonPressed = false),
      onTapCancel: () => setState(() => _isButtonPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.identity()..scale(_isButtonPressed ? 0.97 : 1.0),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _login,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 8,
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.pinkAccent, Colors.deepPurpleAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: _isLoading
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    : const Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Main build method for the login screen.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueAccent.shade100, Colors.purple.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Form(
              key: _formKey, // Form for validation
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildCompanyLogo(),
                  const SizedBox(height: 21.0),
                  _buildCompanyNameText(),
                  const SizedBox(height: 40.0),
                  _buildTextField(
                    _usernameController,
                    'Username',
                    Icons.person_outline,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your username';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20.0),
                  _buildTextField(
                    _passwordController,
                    'Password',
                    Icons.lock_outline,
                    obscureText: !_isPasswordVisible,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.white,
                      ),
                      onPressed: _togglePasswordVisibility,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10.0),
                  _buildBiometricToggle(), // Biometric toggle instead of "Forgot Password?"
                  const SizedBox(height: 30.0),
                  _buildLoginButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
