// change_password.dart

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_service.dart';

// Replace with the actual path

class StorageKeys {
  static const String username = 'username';
  static const String accessToken = 'accessToken';
}

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  _ChangePasswordPageState createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  // Form Key
  final _formKey = GlobalKey<FormState>();

  // Controllers for text fields
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Logger instance
  final Logger _logger = Logger();

  // Secure Storage instance
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Password visibility toggles
  bool _isCurrentPasswordObscured = true;
  bool _isNewPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  // Loading state
  bool _isLoading = false;

  @override
  void dispose() {
    // Dispose controllers to free up resources
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Function to toggle password visibility
  void _togglePasswordVisibility(String field) {
    setState(() {
      switch (field) {
        case 'current':
          _isCurrentPasswordObscured = !_isCurrentPasswordObscured;
          break;
        case 'new':
          _isNewPasswordObscured = !_isNewPasswordObscured;
          break;
        case 'confirm':
          _isConfirmPasswordObscured = !_isConfirmPasswordObscured;
          break;
        default:
      }
    });
  }

  // Function to handle password change
  Future<void> _handleChangePassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Retrieve necessary data from secure storage
        String? username = await _secureStorage.read(key: StorageKeys.username);
        String? accessToken =
            await _secureStorage.read(key: StorageKeys.accessToken);

        // Collect missing keys
        List<String> missingKeys = [];
        if (username == null) missingKeys.add('username');
        if (accessToken == null) missingKeys.add('accessToken');

        if (missingKeys.isNotEmpty) {
          String missing = missingKeys.join(', ');
          _logger.e('Missing necessary user information: $missing');
          _showError(
              'Missing necessary user information: $missing. Please log in again.');
          setState(() {
            _isLoading = false;
          });
          return;
        }

        String oldPassword = _currentPasswordController.text;
        String newPassword = _newPasswordController.text;
        String confirmPassword = _confirmPasswordController.text;

        // Construct the full URL using ApiService.getBaseUrl()
        String url =
            '${ApiService.getBaseUrl()}/api/Account/ChangePasswordCustom';

        _logger.i('Sending password change request to $url');

        // Construct the request body
        Map<String, dynamic> requestBody = {
          "CompanyId": 1, // Use appropriate CompanyId if necessary
          "Username": username,
          "OldPassword": oldPassword,
          "NewPassword": newPassword,
          "ConfirmPassword": confirmPassword
        };

        // Make the POST request
        http.Response response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode(requestBody),
        );

        _logger.i(
            'Password change API responded with status code: ${response.statusCode}');

        if (response.statusCode == 200) {
          // Assuming a successful response contains a success flag/message
          Map<String, dynamic> responseData = jsonDecode(response.body);

          // Modify this based on your actual API response structure
          bool isSuccess = responseData['isSuccess'] ?? false;
          String message =
              responseData['message'] ?? 'Password changed successfully.';

          if (isSuccess) {
            _logger.i('Password changed successfully.');

            // Clear the text fields
            _currentPasswordController.clear();
            _newPasswordController.clear();
            _confirmPasswordController.clear();

            // Show success SnackBar
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Password changed successfully!'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Color.fromARGB(255, 46, 112, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
            );
          } else {
            _logger.w('Password change failed: $message');

            // Show error SnackBar with message from server
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color.fromARGB(255, 29, 99, 29),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
            );
          }
        } else {
          _logger.w(
              'Password change failed with status code: ${response.statusCode}');

          // Attempt to parse error message from server
          String errorMessage = 'Failed to change password. Please try again.';
          try {
            Map<String, dynamic> errorData = jsonDecode(response.body);
            if (errorData.containsKey('message')) {
              errorMessage = errorData['message'];
            }
          } catch (e) {
            _logger.e('Error parsing error response: $e');
          }

          // Show error SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
          );
        }
      } catch (e) {
        _logger.e('Error during password change: $e');

        // Show error SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An error occurred. Please try again later.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Show error message using SnackBar
  void _showError(String message) {
    _logger.e('Showing error SnackBar: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Color.fromARGB(255, 139, 236, 171)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Password'),
      ),
      body: GestureDetector(
        // Dismiss keyboard when tapping outside
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Current Password Field
                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: _isCurrentPasswordObscured,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isCurrentPasswordObscured
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => _togglePasswordVisibility('current'),
                        tooltip: _isCurrentPasswordObscured
                            ? 'Show Password'
                            : 'Hide Password',
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your current password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20.0),

                  // New Password Field
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _isNewPasswordObscured,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isNewPasswordObscured
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => _togglePasswordVisibility('new'),
                        tooltip: _isNewPasswordObscured
                            ? 'Show Password'
                            : 'Hide Password',
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a new password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters long';
                      }
                      // Add more password strength validations if needed
                      return null;
                    },
                  ),
                  const SizedBox(height: 20.0),

                  // Confirm New Password Field
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _isConfirmPasswordObscured,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmPasswordObscured
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => _togglePasswordVisibility('confirm'),
                        tooltip: _isConfirmPasswordObscured
                            ? 'Show Password'
                            : 'Hide Password',
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your new password';
                      }
                      if (value != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 30.0),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleChangePassword,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            )
                          : const Text(
                              'Change Password',
                              style: TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
