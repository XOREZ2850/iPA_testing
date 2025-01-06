import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Secure storage for base URL
import 'dart:convert'; // For encoding and decoding JSON
import 'package:http/http.dart' as http; // HTTP package for network requests

class ApiService {
  // Create an instance of FlutterSecureStorage for securely storing base URL
  static final FlutterSecureStorage _storage = FlutterSecureStorage();

  // Local variable to hold the base URL in memory
  static String? _baseUrl;

  // Load the base URL from secure storage or throw an error if not set
  static Future<void> loadBaseUrl() async {
    _baseUrl = await _storage.read(
        key: 'base_url'); // Read the base URL from secure storage
    if (_baseUrl == null || _baseUrl!.isEmpty) {
      throw Exception('Base URL is not set! Please select a company first.');
    }
  }

  // Set the base URL (call this when the user selects a company)
  static Future<void> setBaseUrl(String baseUrl) async {
    await _storage.write(
        key: 'base_url', value: baseUrl); // Save to secure storage
    _baseUrl = baseUrl; // Set the base URL in memory
  }

  // Get the current base URL (throws an error if not set)
  static String getBaseUrl() {
    if (_baseUrl == null || _baseUrl!.isEmpty) {
      throw Exception('Base URL is not set! Please select a company first.');
    }
    return _baseUrl!;
  }

  // Example GET request
  static Future<Map<String, dynamic>> get(String endpoint) async {
    final url =
        Uri.parse(getBaseUrl() + endpoint); // Combine base URL and endpoint
    final response = await http.get(url); // Send the GET request

    if (response.statusCode == 200) {
      return json.decode(response.body); // Parse the JSON response
    } else {
      throw Exception('Failed to load data from $url');
    }
  }

  // Example POST request
  static Future<Map<String, dynamic>> post(
      String endpoint, Map<String, dynamic> body) async {
    final url =
        Uri.parse(getBaseUrl() + endpoint); // Combine base URL and endpoint
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body), // Encode the body as JSON
    );

    if (response.statusCode == 200) {
      return json.decode(response.body); // Parse the JSON response
    } else {
      throw Exception('Failed to post data to $url');
    }
  }

  // Example PUT request
  static Future<Map<String, dynamic>> put(
      String endpoint, Map<String, dynamic> body) async {
    final url =
        Uri.parse(getBaseUrl() + endpoint); // Combine base URL and endpoint
    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body), // Encode the body as JSON
    );

    if (response.statusCode == 200) {
      return json.decode(response.body); // Parse the JSON response
    } else {
      throw Exception('Failed to update data at $url');
    }
  }

  // Example DELETE request
  static Future<Map<String, dynamic>> delete(String endpoint) async {
    final url =
        Uri.parse(getBaseUrl() + endpoint); // Combine base URL and endpoint
    final response = await http.delete(url); // Send the DELETE request

    if (response.statusCode == 200) {
      return json.decode(response.body); // Parse the JSON response
    } else {
      throw Exception('Failed to delete data at $url');
    }
  }

  // Additional helper methods for other types of API requests (PATCH, etc.) can be added similarly
}
