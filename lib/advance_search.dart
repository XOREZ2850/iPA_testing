import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // For secure storage
import 'package:http/http.dart' as http; // For API calls
import 'package:logger/logger.dart'; // For logging
import 'api_service.dart'; // Ensure ApiService is correctly implemented

class AdvanceSearchPage extends StatefulWidget {
  const AdvanceSearchPage({super.key});

  @override
  _AdvanceSearchPageState createState() => _AdvanceSearchPageState();
}

class _AdvanceSearchPageState extends State<AdvanceSearchPage> {
  final Logger _logger = Logger();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String? _userId;
  String? _accessToken;
  String? _empId;

  // Search criteria
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedEmployee;
  String? _selectedEmployeeId;

  List<Employee> _employees = [];
  List<Employee> _filteredEmployees = [];
  bool _isLoadingEmployees = false;
  bool _isSearching = false;
  List<AttendanceRecord> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  // Load user ID, access token, and empId from secure storage
  Future<void> _loadUserId() async {
    try {
      _userId = await _secureStorage.read(key: 'userId');
      _accessToken = await _secureStorage.read(key: 'accessToken');
      _empId = await _secureStorage.read(key: 'empId');

      if (_userId == null || _accessToken == null || _empId == null) {
        _logger.e('User, token, or employee ID not found in secure storage.');
      }
    } catch (e) {
      _logger.e('Error loading secure storage data: $e');
    }
  }

  // Fetch employee list from the API when selecting employee
  Future<void> _fetchEmployees() async {
    if (_empId == null || _accessToken == null) {
      _logger.e('Employee ID or access token not found.');
      return;
    }

    setState(() {
      _isLoadingEmployees = true;
    });

    try {
      String baseUrl = ApiService.getBaseUrl(); // Get the dynamic base URL
      String url =
          '$baseUrl/api/GENDropDown/GetEmployeesbyReportsTo?Id=$_empId';

      final response = await http.get(Uri.parse(url), headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      });

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);

        // Parse the Key and Value from the response
        setState(() {
          _employees = data.map((json) {
            String fullKey = json['Key'];
            List<String> splitKey = fullKey.split('--');
            return Employee(
              id: json['Value'], // Use Value field for EmpId (numeric part)
              name: splitKey.length > 1 ? splitKey[1] : '', // Employee name
            );
          }).toList();

          // Initially, the filtered employees will be the same as the full list
          _filteredEmployees = List.from(_employees);
          _isLoadingEmployees = false;
        });
      } else {
        _logger.e('Failed to load employees: ${response.statusCode}');
        setState(() {
          _isLoadingEmployees = false;
        });
      }
    } catch (e) {
      _logger.e('Error fetching employees: $e');
      setState(() {
        _isLoadingEmployees = false;
      });
    }
  }

  // Perform the search based on selected criteria
  Future<void> _performSearch() async {
    if (_userId == null) {
      _logger.e('User not authenticated.');
      return;
    }

    // Input Validation: Ensure Start Date is not after End Date
    if (_startDate != null &&
        _endDate != null &&
        _startDate!.isAfter(_endDate!)) {
      _logger.e('Start Date cannot be after End Date.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start Date cannot be after End Date')),
      );
      return;
    }

    // Input Validation: Ensure an employee is selected
    if (_selectedEmployeeId == null || _selectedEmployeeId!.isEmpty) {
      _logger.e('No employee selected.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No employee selected')),
      );
      return;
    }
    setState(() {
      _isSearching = true;
      _searchResults.clear(); // Clear previous results to prevent duplication
    });

    try {
      // Build query parameters
      String formattedStartDate = DateFormat('dd/MM/yyyy').format(_startDate!);
      String formattedEndDate = DateFormat('dd/MM/yyyy').format(_endDate!);

      String baseUrl = ApiService.getBaseUrl();
      String empIdValue = _selectedEmployeeId!; // Get the numeric EmpId

      // Construct the API URL with the numeric EmpId
      String url =
          '$baseUrl/api/EmployeeAttendance/GetAttendanceSummary?EmpID=$empIdValue&SDATE=$formattedStartDate&EDATE=$formattedEndDate&UserId=$_userId';

      _logger.i('API URL: $url'); // Log the full URL for debugging

      final response = await http.get(Uri.parse(url), headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      });

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        List<AttendanceRecord> results =
            data.map((e) => AttendanceRecord.fromJson(e)).toList();

        setState(() {
          _searchResults = results;
          _isSearching = false;
        });

        _logger.i('Search completed successfully.');
      } else {
        _logger.e('Search failed. Status code: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
        setState(() {
          _isSearching = false;
        });
      }
    } catch (e) {
      _logger.e('Error during search: $e');
      setState(() {
        _isSearching = false;
      });
    }
  }

  // Update the list of filtered employees as per search query
  void _filterEmployees(String query) {
    setState(() {
      _filteredEmployees = _employees
          .where((employee) =>
              employee.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  // Pick a date using DatePicker
  Future<void> _pickDate({required bool isStart}) async {
    DateTime initialDate =
        isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now());
    DateTime firstDate = DateTime(2000);
    DateTime lastDate = DateTime(2100);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  // Clear all search criteria
  void _clearSearch() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedEmployee = null;
      _selectedEmployeeId = null;
      _searchResults = [];
    });
  }

  // Build the search criteria input fields
  Widget _buildSearchCriteria() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date Range Picker
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _pickDate(isStart: true),
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Start Date',
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    controller: TextEditingController(
                        text: _startDate != null
                            ? DateFormat('yyyy-MM-dd').format(_startDate!)
                            : ''),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () => _pickDate(isStart: false),
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'End Date',
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    controller: TextEditingController(
                        text: _endDate != null
                            ? DateFormat('yyyy-MM-dd').format(_endDate!)
                            : ''),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Employee Dropdown
        GestureDetector(
          onTap: _fetchEmployees, // Fetch employees when clicked
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Select Employee',
              border: OutlineInputBorder(),
            ),
            child: _isLoadingEmployees
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Search Employee',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: _filterEmployees,
                      ),
                      DropdownButtonFormField<Employee>(
                        value: _selectedEmployeeId != null
                            ? _filteredEmployees.firstWhere((employee) =>
                                employee.id == _selectedEmployeeId)
                            : null,
                        hint: const Text('Select Employee'),
                        items: _filteredEmployees.map((employee) {
                          return DropdownMenuItem<Employee>(
                            value: employee,
                            child: Text(employee.name),
                          );
                        }).toList(),
                        onChanged: (Employee? newValue) {
                          setState(() {
                            _selectedEmployee = newValue?.name;
                            _selectedEmployeeId = newValue?.id;
                          });
                        },
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
        // Search and Clear Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton.icon(
              onPressed: _isSearching ? null : _performSearch,
              icon: const Icon(Icons.search),
              label: const Text('Search'),
            ),
            ElevatedButton.icon(
              onPressed: _clearSearch,
              icon: const Icon(Icons.clear),
              label: const Text('Clear'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Build the search results list
  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return const Center(child: Text('No records found.'));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        var record = _searchResults[index];
        return Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Employee Name
                Text(
                  _selectedEmployee ?? 'Employee',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(),
                // Check-In Details
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.login, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Check-In Time: ${record.checkinTime != null ? DateFormat('yyyy-MM-dd – kk:mm').format(record.checkinTime!) : '--:--'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text('Location: ${record.checkinLocation ?? 'N/A'}'),
                        ],
                      ),
                    ),
                    if (record.imagePath != null &&
                        record.imagePath!.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.image, color: Colors.blue),
                        onPressed: () {
                          _showImageDialog(
                              record.imagePath!); // Handle check-in image
                        },
                        tooltip: 'View Check-In Image',
                      ),
                  ],
                ),

// Check-Out Details
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.logout, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Check-Out Time: ${record.checkoutTime != null ? DateFormat('yyyy-MM-dd – kk:mm').format(record.checkoutTime!) : '--:--'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text('Location: ${record.checkoutLocation ?? 'N/A'}'),
                        ],
                      ),
                    ),
                    if (record.checkoutImagePath != null &&
                        record.checkoutImagePath!.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.image, color: Colors.blue),
                        onPressed: () {
                          _showImageDialog(record
                              .checkoutImagePath!); // Handle checkout image
                        },
                        tooltip: 'View Check-Out Image',
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Show image in a dialog
  void _showImageDialog(String imagePath) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: imagePath.startsWith('http')
              ? Image.network(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Failed to load image'),
                    );
                  },
                )
              : Image.file(
                  File(imagePath),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Failed to load image'),
                    );
                  },
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advance Search'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSearchCriteria(),
            const SizedBox(height: 16),
            Expanded(child: _buildSearchResults()),
          ],
        ),
      ),
    );
  }
}

// Employee model
class Employee {
  final String id;
  final String name;

  Employee({required this.id, required this.name});

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['Value'].toString(), // Extract EmpId from 'Value'
      name: json['Key'],
    );
  }
}

// Attendance Record model
class AttendanceRecord {
  final String? employeeId;
  final DateTime? checkinTime;
  final DateTime? checkoutTime;
  final String? checkinLocation;
  final String? checkoutLocation;
  final String? imagePath;
  final String? checkoutImagePath;

  AttendanceRecord({
    this.employeeId,
    this.checkinTime,
    this.checkoutTime,
    this.checkinLocation,
    this.checkoutLocation,
    this.imagePath,
    this.checkoutImagePath,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      employeeId: json['EMP_ID'],
      checkinTime: json['ATTN_TIME_IN'] != null
          ? DateTime.parse(json['ATTN_TIME_IN'])
          : null,
      checkinLocation: json['LOCATION'],
      imagePath: json['ATTN_IN_IMAGE'],
      checkoutTime: json['ATTN_TIME_OUT'] != null
          ? DateTime.parse(json['ATTN_TIME_OUT'])
          : null,
      checkoutLocation: json['LOCATION'],
      checkoutImagePath: json['ATTN_OUT_IMAGE'],
    );
  }
}
