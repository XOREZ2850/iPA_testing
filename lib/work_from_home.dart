// work_from_home.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart'; // Ensure this file contains ApiService.getBaseUrl()

/// AuthService to handle authentication-related functionalities
class AuthService {
  final FlutterSecureStorage storage;

  AuthService({required this.storage});

  /// Retrieves the authentication headers including the Bearer token.
  Future<Map<String, String>> getAuthHeaders() async {
    String? accessToken = await storage.read(key: 'accessToken');
    // Removed sensitive token logging for security
    if (accessToken == null) {
      throw Exception('Authentication token not found');
    }
    return {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };
  }

  /// Retrieves the stored user ID.
  Future<String> getUserId() async {
    String? userId = await storage.read(key: 'userId');
    print('Retrieved userId: $userId');
    if (userId == null) {
      throw Exception('User ID not found in secure storage');
    }
    return userId;
  }

  /// Retrieves the stored username.
  Future<String> getUsername() async {
    String? username = await storage.read(key: 'username');
    print('Retrieved username: $username');
    if (username == null) {
      throw Exception('Username not found in secure storage');
    }
    return username;
  }
}

/// Model class for LeaveRequest
class LeaveRequest {
  final String userId;
  final String empId;
  final String employeeName; // New field
  final String draftNumber;
  final String documentNumber;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String leaveNature;
  final String status;

  LeaveRequest({
    required this.userId,
    required this.empId,
    required this.employeeName, // Initialize the new field
    required this.draftNumber,
    required this.documentNumber,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.leaveNature,
    required this.status,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    return LeaveRequest(
      userId: json['userId'] ?? 'N/A',
      empId: json['empId'] ?? 'N/A',
      employeeName: json['employeeName'] ?? 'N/A', // Deserialize the new field
      draftNumber: json['draftNumber'] ?? 'N/A',
      documentNumber: json['documentNumber'] ?? 'N/A',
      leaveType: json['leaveType'] ?? 'N/A',
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      leaveNature: json['leaveNature'] ?? 'N/A',
      status: json['status'] ?? 'Pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'empId': empId,
      'employeeName': employeeName, // Serialize the new field
      'draftNumber': draftNumber,
      'documentNumber': documentNumber,
      'leaveType': leaveType,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'leaveNature': leaveNature,
      'status': status,
    };
  }
}

class WorkFromHomeForm extends StatefulWidget {
  const WorkFromHomeForm({super.key});

  @override
  _WorkFromHomeFormState createState() => _WorkFromHomeFormState();
}

class _WorkFromHomeFormState extends State<WorkFromHomeForm> {
  // Form Fields
  String? selectedEmployee;
  DateTime? startDate;
  DateTime? endDate;

  // Controllers
  TextEditingController reasonController = TextEditingController();
  TextEditingController startDateController = TextEditingController();
  TextEditingController endDateController = TextEditingController();

  // Data Variables
  Map<String, String> employeeDetails = {};
  List<Map<String, String>> employeeList = [];
  // Since Leave Type is static for Work From Home, no need for leaveTypeList

  // Secure Storage and AuthService
  final storage = FlutterSecureStorage();
  late AuthService authService;

  // Visibility Toggles
  bool showEmployeeDetails = false;
  bool showLeaveStatus = false;
  bool showDocumentFields = false; // New toggle for document fields

  // Leave Status Data (Simplified)
  Map<String, dynamic> leaveStatus = {};
  Map<String, dynamic> simplifiedLeaveStatus = {};

  // Document Fields Data
  String? docDraftNo;
  String? docNo;
  String? documentDate;
  String documentStatus = "Draft";
  String draftApprovalStatus = "Pending";
  String branch = "Faisalabad";
  String? officeRefNumber;
  String? serialNo; // New state variable for SERIAL_NO

  // New State Variable for LEAVE_TYPE_SETUP_CODE
  String? leaveTypeSetupCode;

  // Form Key
  final _formKey = GlobalKey<FormState>();

  // Loading Indicators
  bool isSubmitting = false; // Add this state variable
  bool isLoadingEmployees = true; // New state variable for employee loading

  // Leave Nature is set to 'Full Day' by default
  String selectedLeaveNature = 'Full Day'; // Default value

  @override
  void initState() {
    super.initState();
    authService = AuthService(storage: storage);
    // Initialize default values
    selectedLeaveNature = 'Full Day'; // Set to 'Full Day' by default
    startDate = DateTime.now();
    endDate = DateTime.now();
    startDateController.text = DateFormat('dd/MM/yyyy').format(startDate!);
    endDateController.text = DateFormat('dd/MM/yyyy').format(endDate!);
    fetchEmployeeList();
    // Optionally, you can fetch leave status and document codes here if needed
  }

  /// Fetches the list of employees from the API and populates the employee dropdown.
  Future<void> fetchEmployeeList() async {
    setState(() {
      isLoadingEmployees = true; // Start loading
    });
    try {
      final headers = await authService.getAuthHeaders();
      final userId = await authService.getUserId();

      print('Fetching employee list with UserID: $userId');

      String baseUrl = ApiService.getBaseUrl(); // Dynamically fetch base URL
      String url =
          '$baseUrl/api/HRMDropdowns/EmployeeComboForHR?LicId=1&CompId=1&UserID=$userId';

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      print('Employee List API Response Status: ${response.statusCode}');
      print('Employee List API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        setState(() {
          employeeList = data
              .where((employee) =>
                  employee['Value'] != null && employee['Key'] != null)
              .map<Map<String, String>>((employee) {
            return {
              'id': employee['Value'].toString(), // 'Value' contains EmpId
              'name': employee['Key'] ?? '', // 'Key' contains Employee Name
            };
          }).toList();
          isLoadingEmployees = false; // Employee loading completed
        });
        print('Employee List: $employeeList'); // Debugging
      } else {
        print(
            'Failed to load employee list. Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
        setState(() {
          isLoadingEmployees = false; // Stop loading on error
        });
        throw Exception('Failed to load employee list');
      }
    } catch (e) {
      print('Error fetching employee list: $e');
      setState(() {
        isLoadingEmployees = false; // Stop loading on error
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error fetching employee list: ${e.toString()}')),
      );
    }
  }

  /// Fetches the details of the selected employee from the API.
  Future<void> fetchEmployeeDetails(String? employeeId) async {
    if (employeeId == null) {
      setState(() {
        employeeDetails = {};
        leaveTypeSetupCode = null;
      });
      return;
    }

    try {
      final headers = await authService.getAuthHeaders();

      print('Fetching employee details for EmpId: $employeeId');

      String baseUrl = ApiService.getBaseUrl(); // Dynamically fetch base URL
      String url =
          '$baseUrl/api/LeaveRequest/GetEmployeeDetailsById?CompanyId=1&BranchId=1&EmpId=$employeeId';

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
      );

      print('Employee Details API Response Status: ${response.statusCode}');
      print('Employee Details API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Verify if EMP_DETAILS exists
        if (data['EMP_DETAILS'] != null) {
          setState(() {
            // Update employeeDetails with correct keys from EMP_DETAILS
            employeeDetails = {
              'Branch': data['EMP_DETAILS']['EMP_BRANCH'] ?? '',
              'Gender': data['EMP_DETAILS']['EMP_GENDER'] ?? '',
              'Department': data['EMP_DETAILS']['EMP_DEPT'] ?? '',
              'Designation': data['EMP_DETAILS']['EMP_DESG'] ?? '',
              'Joining Date': data['EMP_DETAILS']['EMP_JOINING_DATE'] != null
                  ? DateFormat('dd/MM/yyyy').format(
                      DateTime.parse(data['EMP_DETAILS']['EMP_JOINING_DATE']))
                  : '',
              'Grade/Scale': data['EMP_DETAILS']['EMP_GRADE_SCALE'] ?? '',
              'Contract Type': data['EMP_DETAILS']['EMP_CONTRACT_TYPE'] ?? '',
            };
            // Extract LEAVE_TYPE_SETUP_CODE
            leaveTypeSetupCode =
                data['EMP_DETAILS']['LEAVE_TYPE_SETUP_CODE'] ?? '';
          });
        } else {
          print('EMP_DETAILS not found in the response.');
          setState(() {
            employeeDetails = {};
            leaveTypeSetupCode = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Employee details not found.')),
          );
        }
      } else {
        print(
            'Failed to load employee details. Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
        throw Exception('Failed to load employee details');
      }
    } catch (e) {
      print('Error fetching employee details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error fetching employee details: ${e.toString()}')),
      );
    }
  }

  /// Fetches the leave status for the selected employee and leave type (API 3).
  Future<void> fetchLeaveStatus(String employeeId, String leaveTypeId) async {
    try {
      final headers = await authService.getAuthHeaders();
      print(
          'Fetching leave status for EmpId: $employeeId, LeaveTypeId: $leaveTypeId');

      String baseUrl = ApiService.getBaseUrl(); // Dynamically fetch base URL
      String url =
          '$baseUrl/api/LeaveRequest/GetLeaveTypeDetailsOpenQuota?CompanyId=1&BranchId=1&EmpId=$employeeId&LeaveTypeId=$leaveTypeId';

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
      );

      print('Leave Status API Response Status: ${response.statusCode}');
      print('Leave Status API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          leaveStatus = data;
          simplifiedLeaveStatus = mapToSimplifiedLeaveStatus(data);
        });
      } else {
        print(
            'Failed to load leave status. Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
        throw Exception('Failed to load leave status');
      }
    } catch (e) {
      print('Error fetching leave status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching leave status: ${e.toString()}')),
      );
    }
  }

  /// Fetches document codes from the API and populates the document fields.
  Future<void> fetchDocumentCodes() async {
    try {
      final headers = await authService.getAuthHeaders();

      // Use the selected start date or current date if not selected
      DateTime docDate = startDate ?? DateTime.now();
      String formattedDate = DateFormat('dd/MM/yyyy').format(docDate);

      String baseUrl = ApiService.getBaseUrl(); // Dynamically fetch base URL
      String url =
          '$baseUrl/api/FINCommon/GetDocumentCode?licId=1&companyId=1&branchId=2&docTypeId=124&documentDate=$formattedDate&Mode=0';

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      print('Document Code API Response Status: ${response.statusCode}');
      print('Document Code API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          docDraftNo = data['DOC_DRAFT_NO'] ?? 'LHR-LVR-24-NOV-18';
          docNo = data['DOC_NO']; // Can be null
          documentDate = formattedDate;
          // Assuming Office Ref Number is SERIAL_NO from response
          officeRefNumber = data['SERIAL_NO']?.toString() ?? '';
          serialNo = data['SERIAL_NO']?.toString() ??
              ''; // Store SERIAL_NO separately if needed
          showDocumentFields = true; // Show the document fields
        });
      } else {
        print(
            'Failed to load document codes. Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
        throw Exception('Failed to load document codes');
      }
    } catch (e) {
      print('Error fetching document codes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error fetching document codes: ${e.toString()}')),
      );
    }
  }

  /// Maps the detailed leaveStatus JSON to simplifiedLeaveStatus with required fields.
  Map<String, dynamic> mapToSimplifiedLeaveStatus(Map<String, dynamic> data) {
    // Initialize variables with default values
    double totalEntitled = 0;
    double accruedYTOD = 0;
    double availedApproved = 0;
    double availedUnapproved = 0;
    double encashedLeaves = 0;
    double penaltyLeaves = 0;
    double balance = 0;

    // Extract and calculate the required fields from LEAVE_QUOTA_DETAILS
    if (data['LEAVE_QUOTA_DETAILS'] != null) {
      // Total Entitled = YEARLY_ENTITLE + ADDITIONAL_ENTITLE + CARRY_FWD_BAL
      totalEntitled = double.tryParse(
              data['LEAVE_QUOTA_DETAILS']['YEARLY_ENTITLE']?.toString() ??
                  '0') ??
          0;
      totalEntitled += double.tryParse(
              data['LEAVE_QUOTA_DETAILS']['ADDITIONAL_ENTITLE']?.toString() ??
                  '0') ??
          0;
      totalEntitled += double.tryParse(
              data['LEAVE_QUOTA_DETAILS']['CARRY_FWD_BAL']?.toString() ??
                  '0') ??
          0;

      // Accrued (YTOD)
      accruedYTOD = double.tryParse(
              data['LEAVE_QUOTA_DETAILS']['ACCRUED_DAYS']?.toString() ?? '0') ??
          0;

      // Encashed Leaves
      encashedLeaves = double.tryParse(
              data['LEAVE_QUOTA_DETAILS']['ENCASHED_LEAVE']?.toString() ??
                  '0') ??
          0;

      // Penalty Leaves
      penaltyLeaves = double.tryParse(
              data['LEAVE_QUOTA_DETAILS']['PENALTY_LEAVE']?.toString() ??
                  '0') ??
          0;

      // Availed (Approved)
      availedApproved = double.tryParse(
              data['LEAVE_QUOTA_DETAILS']['LEAVE_TAKEN']?.toString() ?? '0') ??
          0;

      // Availed (Unapproved)
      availedUnapproved = double.tryParse(
              data['LEAVE_QUOTA_DETAILS']['LEAVE_PENDING']?.toString() ??
                  '0') ??
          0;
    }

    // Calculate Balance
    balance = totalEntitled +
        accruedYTOD -
        (availedApproved + availedUnapproved + encashedLeaves + penaltyLeaves);

    return {
      'Total Entitled': totalEntitled,
      'Accrued (YTOD)': accruedYTOD,
      'Availed (Approved)': availedApproved,
      'Availed (Unapproved)': availedUnapproved,
      'Encashed Leaves': encashedLeaves,
      'Penalty Leaves': penaltyLeaves,
      'Balance': balance,
    };
  }

  /// Maps the selected leave nature to its corresponding string value.
  String mapLeaveNatureToString(String? leaveNature) {
    switch (leaveNature) {
      case 'Full Day':
        return "0";
      case 'First Half':
        return "1";
      case 'Second Half':
        return "2";
      default:
        return "0"; // Default value or handle as needed
    }
  }

  /// Calculates the total leave days based on start and end dates.
  String calculateTotalLeaveDays() {
    if (startDate != null && endDate != null) {
      return (endDate!.difference(startDate!).inDays + 1).toString();
    }
    return "1";
  }

  /// Saves a leave request to local storage using SharedPreferences
  Future<void> saveLeaveRequest(LeaveRequest leave) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> leaveList = prefs.getStringList('leaveHistory') ?? [];

    leaveList.add(json.encode(leave.toJson()));
    await prefs.setStringList('leaveHistory', leaveList);
  }

  @override
  void dispose() {
    reasonController.dispose();
    startDateController.dispose();
    endDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar with consistent background color
      appBar: AppBar(
        title: Text('Avail Work from Home'),
        backgroundColor: Colors.green,
      ),
      body: Container(
        color: Colors.white, // Set background color to white
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey, // Add the form key
            child: Column(
              children: [
                // Employee Dropdown with Loading Indicator
                isLoadingEmployees
                    ? Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(
                              color: Colors.green,
                              strokeWidth: 4.0,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Loading Employees...',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        isExpanded:
                            true, // Ensures the dropdown takes full width
                        decoration: InputDecoration(
                          labelText: 'Employee',
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(15), // Rounded corners
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        value: selectedEmployee,
                        onChanged: (newValue) {
                          if (newValue != null) {
                            print(
                                'Selected Employee ID: $newValue'); // Debugging
                            setState(() {
                              selectedEmployee = newValue;
                              // Reset dependent fields
                              showLeaveStatus = false;
                              leaveStatus = {};
                              simplifiedLeaveStatus = {};
                              // Leave Type is static "Work From Home"
                              // No need to reset leave type fields
                              // No Replacement Employee Field
                              // Reset Document Fields when Employee changes
                              docDraftNo = null;
                              docNo = null;
                              documentDate = null;
                              officeRefNumber = null;
                              serialNo = null;
                              showDocumentFields = false;
                              leaveTypeSetupCode = null;
                            });
                            fetchEmployeeDetails(newValue).then((_) {
                              // After fetching employee details, fetch leave status
                              // Assuming "Work From Home" has a specific Leave Type ID, e.g., '4'
                              String workFromHomeLeaveTypeId =
                                  '4'; // Example ID
                              fetchLeaveStatus(
                                  selectedEmployee!, workFromHomeLeaveTypeId);
                            });
                          }
                        },
                        validator: (value) =>
                            value == null ? 'Please select an employee' : null,
                        items: employeeList.map((employee) {
                          return DropdownMenuItem(
                            value: employee['id'],
                            child: Text(
                              employee['name'] ?? '',
                              overflow:
                                  TextOverflow.ellipsis, // Prevents overflow
                              maxLines: 1,
                            ),
                          );
                        }).toList(),
                      ),
                SizedBox(height: 16),

                // Employee Details Title with Eye Icon
                if (selectedEmployee != null)
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Employee Details',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black),
                          ),
                          IconButton(
                            icon: Icon(
                              showEmployeeDetails
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.black,
                            ),
                            onPressed: () {
                              setState(() {
                                showEmployeeDetails = !showEmployeeDetails;
                              });
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      if (showEmployeeDetails && employeeDetails.isNotEmpty)
                        ...employeeDetails.entries.map((entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: TextFormField(
                                decoration: InputDecoration(
                                  labelText: entry.key,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                readOnly: true,
                                initialValue: entry.value,
                              ),
                            ))
                      else if (showEmployeeDetails && employeeDetails.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'No details available for the selected employee.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                    ],
                  ),

                SizedBox(height: 16),

                // Leave Status Title with Eye Icon
                if (selectedEmployee != null)
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Leave Status',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black),
                          ),
                          IconButton(
                            icon: Icon(
                              showLeaveStatus
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.black,
                            ),
                            onPressed: () {
                              setState(() {
                                showLeaveStatus = !showLeaveStatus;
                              });
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      if (showLeaveStatus && simplifiedLeaveStatus.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: simplifiedLeaveStatus.entries
                              .map((entry) => Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 16.0),
                                    child: TextFormField(
                                      decoration: InputDecoration(
                                        labelText: entry.key,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(15),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                      readOnly: true,
                                      initialValue: entry.value.toString(),
                                    ),
                                  ))
                              .toList(),
                        )
                      else if (showLeaveStatus && simplifiedLeaveStatus.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'No leave status available for the selected employee and leave type.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                    ],
                  ),

                SizedBox(height: 16),

                // Start Date Picker (Auto-Populated)
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Start Date',
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(15), // Rounded corners
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  controller: startDateController,
                  readOnly: true,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Select start date'
                      : null,
                  onTap: () async {
                    DateTime initialDate = startDate ?? DateTime.now();
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: initialDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
                    );
                    if (pickedDate != null) {
                      setState(() {
                        startDate = pickedDate;
                        startDateController.text =
                            DateFormat('dd/MM/yyyy').format(pickedDate);
                        // Clear end date if it's before the new start date
                        if (endDate != null && endDate!.isBefore(startDate!)) {
                          endDate = null;
                          endDateController.clear();
                        }
                      });
                      // Fetch Document Codes when Start Date is selected
                      fetchDocumentCodes();
                    }
                  },
                ),
                SizedBox(height: 16),

                // End Date Picker (Auto-Populated)
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'End Date',
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(15), // Rounded corners
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  controller: endDateController,
                  readOnly: true,
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Select end date' : null,
                  onTap: () async {
                    if (startDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Please select a start date first')),
                      );
                      return;
                    }
                    DateTime initialDate = startDate!;
                    if (endDate != null) {
                      initialDate = endDate!;
                    }
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: initialDate,
                      firstDate: startDate!,
                      lastDate: DateTime(2101),
                    );
                    if (pickedDate != null) {
                      if (pickedDate.isBefore(startDate!)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('End date cannot be before start date')),
                        );
                        return;
                      }
                      setState(() {
                        endDate = pickedDate;
                        endDateController.text =
                            DateFormat('dd/MM/yyyy').format(pickedDate);
                      });
                    }
                  },
                ),
                SizedBox(height: 16),

                // Reason for Work from Home
                TextFormField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText: 'Reason for Work from Home',
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(15), // Rounded corners
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  maxLines: 3,
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Enter reason' : null,
                ),
                SizedBox(height: 16),

                // Document Fields Title with Eye Icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Document Details',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black),
                    ),
                    IconButton(
                      icon: Icon(
                        showDocumentFields
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.black,
                      ),
                      onPressed: () {
                        setState(() {
                          showDocumentFields = !showDocumentFields;
                        });
                      },
                    ),
                  ],
                ),
                SizedBox(height: 8),
                if (showDocumentFields)
                  Column(
                    children: [
                      // Draft Number
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Draft Number',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        readOnly: true,
                        initialValue: docDraftNo ?? '',
                      ),
                      SizedBox(height: 16),

                      // Document Number
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Document Number',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        readOnly: true,
                        initialValue: docNo ?? '',
                      ),
                      SizedBox(height: 16),

                      // Document Date
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Document Date',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        readOnly: true,
                        initialValue: documentDate ?? '',
                      ),
                      SizedBox(height: 16),

                      // Document Status
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Document Status',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        readOnly: true,
                        initialValue: documentStatus,
                      ),
                      SizedBox(height: 16),

                      // Draft Approval Status
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Draft Approval Status',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        readOnly: true,
                        initialValue: draftApprovalStatus,
                      ),
                      SizedBox(height: 16),

                      // Pending
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Pending',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        readOnly: true,
                      ),
                      SizedBox(height: 16),

                      // Branch
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Branch',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        readOnly: true,
                        initialValue: branch,
                      ),
                      SizedBox(height: 16),

                      // Office Ref Number
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Office Ref Number',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        readOnly: true,
                        initialValue: officeRefNumber ?? '',
                      ),
                      SizedBox(height: 16),
                    ],
                  ),

                SizedBox(height: 16),

                // Submit Button with Green Background
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      textStyle:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(15), // Rounded corners
                      ),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () {
                            submitLeaveRequest();
                          },
                    child: isSubmitting
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text('Submit Work from Home Request'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Submits the Work from Home request to the API.
  Future<void> submitLeaveRequest() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        isSubmitting = true;
      });
      try {
        final headers = await authService.getAuthHeaders();
        final userId = await authService.getUserId();

        // Prepare the leave request data matching the provided JSON model
        final leaveRequest = {
          "LIC_ID": "1", // Static value as per model
          "CO_ID": "1", // Static value as per model
          "PRL_LEAVE_REQ_ID": 0, // Static value as per model
          "USER_ID": userId, // Retrieved from AuthService
          "DOC_DRAFT_NO":
              docDraftNo ?? "LHR-LVR-24-NOV-18", // From fetched document codes
          "DOC_NO": docNo, // From fetched document codes, can be null
          "DOC_TYPE_ID": 124, // Static value as per model
          "DOC_DATE": documentDate ??
              DateFormat('dd/MM/yyyy').format(DateTime
                  .now()), // From fetched document codes or current date
          "SERIAL_DRAFT_NO": 18, // Static value as per model
          "SERIAL_NO": serialNo != null && serialNo!.isNotEmpty
              ? int.parse(serialNo!)
              : 0, // From fetched document codes
          "DOC_STATUS": "0", // Static value as per model
          "APV_CYCLE": 0, // Static value as per model
          "APV_STATUS": 0, // Static value as per model
          "CO_BRANCH_ID": "1", // Static value as per model
          "IS_PAID": true, // Static value as per model
          "IS_SL_DEDUCTION": false, // Static value as per model
          "OFFICE_REQ_NO": "", // Static value as per model
          "EMP_ID": selectedEmployee!, // From dropdown selection
          "PENLTY_LEAVE": "0", // Static value as per model
          "LEAVE_TYPE_ID": 1, // From dropdown selection
          "LEAVE_TYPE_SETUP_CODE":
              leaveTypeSetupCode ?? "HLT003", // From fetched employee details
          "LEAVE_NATURE": 1, // Mapped from dropdown selection
          "LEAVE_SDATE": startDate != null
              ? DateFormat('dd/MM/yyyy').format(startDate!)
              : DateFormat('dd/MM/yyyy')
                  .format(DateTime.now()), // From date picker
          "LEAVE_EDATE": endDate != null
              ? DateFormat('dd/MM/yyyy').format(endDate!)
              : DateFormat('dd/MM/yyyy')
                  .format(DateTime.now()), // From date picker
          "TOTAL_LEAVE_DAYS":
              calculateTotalLeaveDays(), // Calculated based on dates
          "REPLACE_EMP_ID": 1, // From dropdown selection
          "EX_COUNTRY_ID": 1, // Static value as per model
          "VISIT_VENUE": "", // Static value as per model
          "LAST_LEAVE_DETAIL": "", // Static value as per model
          "IS_LEAVE_SAL_CLAIM": false, // Static value as per model
          "ABROAD_EXPENSES_DETAIL": "", // Static value as per model
          "REF_ATTACH_DOC_ID": "", // Static value as per model
          "REMARKS": reasonController.text, // From user input
          "HRM_FY_ID": null, // Static value as per model
          "USER_DEPT_ID": 1, // Static value as per model
          "CREATED_BY": "admin", // Static value as per model
          "CREATED_DATE": DateTime.now()
              .toUtc()
              .toIso8601String(), // Current UTC time in ISO8601
          "MODIFY_BY": "admin", // Static value as per model
          "MODIFY_DATE": DateTime.now()
              .toUtc()
              .toIso8601String(), // Current UTC time in ISO8601
          "CPL_DETAILS_IDS": [] // Empty list as per model
        };

        // Log the leave request data being submitted for debugging
        print(
            'Submitting Work from Home Request: ${json.encode(leaveRequest)}');

        // **Ensure the correct API endpoint is used for submitting leave requests.**
        String baseUrl = ApiService.getBaseUrl(); // Dynamically fetch base URL
        String url =
            '$baseUrl/api/LeaveRequest/CreateLeaveRequest'; // Correct endpoint

        // Make the POST request with headers and body
        final response = await http.post(
          Uri.parse(url),
          headers: headers, // Add any necessary headers
          body: json.encode(leaveRequest),
        );

        print(
            'Submit Work from Home Request API Response Status: ${response.statusCode}');
        print(
            'Submit Work from Home Request API Response Body: ${response.body}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          // Handle success
          print('Work from Home request submitted successfully.');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Work from Home request submitted successfully')),
          );

          // Retrieve employee name from employeeList
          String employeeName = employeeList.firstWhere(
                  (employee) => employee['id'] == selectedEmployee,
                  orElse: () => {'name': 'N/A'})['name'] ??
              'N/A';

          // Create a LeaveRequest object
          LeaveRequest newLeave = LeaveRequest(
            userId: userId,
            empId: selectedEmployee!,
            employeeName: employeeName, // Include employee name
            draftNumber: docDraftNo ?? "LHR-LVR-24-NOV-18",
            documentNumber: docNo ?? "N/A",
            leaveType: 'Work From Home', // Static Leave Type
            startDate: startDate ?? DateTime.now(),
            endDate: endDate ?? DateTime.now(),
            leaveNature: selectedLeaveNature,
            status: "Pending",
          );

          // Save the leave request locally
          await saveLeaveRequest(newLeave);

          // Clear the form
          _formKey.currentState!.reset();
          setState(() {
            selectedEmployee = null;
            // Leave Type is static "Work From Home"
            // No need to reset leave type fields
            selectedLeaveNature = 'Full Day'; // Reset to 'Full Day'
            // No Replacement Employee Field
            startDate = DateTime.now();
            endDate = DateTime.now();
            startDateController.text =
                DateFormat('dd/MM/yyyy').format(startDate!);
            endDateController.text = DateFormat('dd/MM/yyyy').format(endDate!);
            employeeDetails = {};
            leaveStatus = {};
            simplifiedLeaveStatus = {};
            // Clear Document Fields
            docDraftNo = null;
            docNo = null;
            documentDate = null;
            officeRefNumber = null;
            serialNo = null;
            showDocumentFields = false;
            leaveTypeSetupCode = null;
          });
        } else {
          // Handle error
          final responseBody = json.decode(response.body);
          print(
              'Failed to submit Work from Home request: ${responseBody['Message'] ?? 'Unknown error'}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Failed to submit Work from Home request: ${responseBody['Message'] ?? 'Unknown error'}')),
          );
        }
      } catch (e) {
        print('Error submitting Work from Home request: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Error submitting Work from Home request: ${e.toString()}')),
        );
      } finally {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }
}
