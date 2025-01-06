import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'work_from_home.dart';

/// AuthService to handle authentication-related functionalities
class AuthService {
  final FlutterSecureStorage storage;

  AuthService({required this.storage});

  /// Retrieves the authentication headers including the Bearer token.
  Future<Map<String, String>> getAuthHeaders() async {
    String? accessToken = await storage.read(key: 'accessToken');
    print('Retrieved accessToken: ${accessToken != null ? "****" : null}');
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

class LeavesPage extends StatelessWidget {
  const LeavesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar with a consistent background color
      appBar: AppBar(
        title: Text('Leave Management'),
        backgroundColor: Colors.green,
      ),
      body: Container(
        color: Colors.white, // Set background color to white
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Apply for Leave Card
            Card(
              color: const Color.fromARGB(255, 248, 246, 246),
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15), // Rounded corners
              ),
              child: ListTile(
                leading: Icon(Icons.add_circle, color: Colors.black, size: 50),
                title: Text(
                  'Apply for Leave',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 31, 2, 2)),
                ),
                subtitle: Text(
                  'Click here to apply for a new leave request',
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LeaveForm()),
                  );
                },
              ),
            ),
            SizedBox(height: 20),
            // Avail Work from Home Card
            Card(
              color: const Color.fromARGB(255, 248, 246, 246),
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15), // Rounded corners
              ),
              child: ListTile(
                leading: Icon(Icons.home, color: Colors.black, size: 50),
                title: Text(
                  'Avail Work from Home',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 31, 2, 2)),
                ),
                subtitle: Text(
                  'Click here to avail work from home',
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => WorkFromHomeForm()),
                  );
                },
              ),
            ),
            SizedBox(height: 20)

            // Leaves History Card
            ,
            Card(
              color: Colors.white,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15), // Rounded corners
              ),
              child: ListTile(
                leading: Icon(Icons.history, color: Colors.black, size: 50),
                title: Text(
                  'Leave History',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
                subtitle: Text(
                  'View your previous leave requests',
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
                onTap: () {
                  // Navigate to Leave History Page
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LeaveHistoryPage()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LeaveForm extends StatefulWidget {
  const LeaveForm({super.key});

  @override
  _LeaveFormState createState() => _LeaveFormState();
}

class _LeaveFormState extends State<LeaveForm> {
  // Form Fields
  String? selectedEmployee;
  String? selectedLeaveTypeId;
  String? selectedLeaveTypeName;
  String? selectedLeaveNature;
  String? selectedReplacementEmployee;
  DateTime? startDate;
  DateTime? endDate;

  // Controllers
  TextEditingController reasonController = TextEditingController();
  TextEditingController startDateController = TextEditingController();
  TextEditingController endDateController = TextEditingController();

  // Data Variables
  Map<String, String> employeeDetails = {};
  List<Map<String, String>> employeeList = [];
  List<Map<String, String>> leaveTypeList = [
    {'id': '1', 'name': 'Annual Leave'},
    {'id': '2', 'name': 'Sick Leave'},
    {'id': '3', 'name': 'Casual Leave'},
    // Add more leave types here as needed
  ];

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
  String pending = "Pending";
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

  @override
  void initState() {
    super.initState();
    authService = AuthService(storage: storage);
    // Initialize default values
    selectedLeaveTypeId = '1'; // Set to 'Annual Leave' by default
    selectedLeaveNature = 'Full Day'; // Set to 'Full Day' by default
    startDate = DateTime.now();
    endDate = DateTime.now();
    startDateController.text = DateFormat('dd/MM/yyyy').format(startDate!);
    endDateController.text = DateFormat('dd/MM/yyyy').format(endDate!);
    fetchEmployeeList();
    // testStorage(); // Uncomment for testing and remove after verification
  }

  /// Test function to verify storage (Optional)
  Future<void> testStorage() async {
    // Store test data
    await storage.write(key: 'accessToken', value: 'test_access_token');
    await storage.write(key: 'userId', value: 'test_user_id');
    await storage.write(
        key: 'username', value: 'test_username'); // Added for testing

    // Retrieve test data
    String? testToken = await storage.read(key: 'accessToken');
    String? testUserId = await storage.read(key: 'userId');
    String? testUsername =
        await storage.read(key: 'username'); // Retrieve username

    print('Test accessToken: $testToken');
    print('Test userId: $testUserId');
    print('Test username: $testUsername'); // Print username
  }

  /// Fetches the list of employees from the first API and populates the employee dropdown.
  Future<void> fetchEmployeeList() async {
    try {
      final headers = await authService.getAuthHeaders();
      final userId = await authService.getUserId();

      print('Fetching employee list with UserID: $userId');

      final response = await http.get(
        Uri.parse(
            'https://api.teckmech.com:8083/api/HRMDropdowns/EmployeeComboForHR?LicId=1&CompId=1&UserID=$userId'),
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

  /// Fetches the details of the selected employee from the second API.
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

      final response = await http.post(
        Uri.parse(
            'https://api.teckmech.com:8083/api/LeaveRequest/GetEmployeeDetailsById?CompanyId=1&BranchId=1&EmpId=$employeeId'),
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

      final response = await http.post(
        Uri.parse(
            'https://api.teckmech.com:8083/api/LeaveRequest/GetLeaveTypeDetailsOpenQuota?CompanyId=1&BranchId=1&EmpId=$employeeId&LeaveTypeId=$leaveTypeId'),
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

      final response = await http.get(
        Uri.parse(
            'http://203.99.60.121:8090/FINCommon/GetDocumentCode?licId=1&companyId=1&branchId=2&docTypeId=124&documentDate=$formattedDate&Mode=0'),
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
    // Filtered list for Replacement Employee excluding the selected Employee
    List<Map<String, String>> filteredReplacementEmployees =
        selectedEmployee == null
            ? employeeList
            : employeeList
                .where((employee) => employee['id'] != selectedEmployee)
                .toList();

    return Scaffold(
      // AppBar with consistent background color
      appBar: AppBar(
        title: Text('Apply for Leave'),
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
                // Employee Dropdown
                isLoadingEmployees
                    ? Center(child: CircularProgressIndicator())
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
                              selectedLeaveTypeId =
                                  '1'; // Reset to 'Annual Leave'
                              selectedLeaveTypeName = 'Annual Leave';
                              selectedLeaveNature =
                                  'Full Day'; // Reset to 'Full Day'
                              // If Replacement Employee is the same as the new selected Employee, reset it
                              if (selectedReplacementEmployee ==
                                  selectedEmployee) {
                                selectedReplacementEmployee = null;
                              }
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
                              // After fetching employee details, fetch leave status if Leave Type is selected
                              if (selectedLeaveTypeId != null) {
                                fetchLeaveStatus(
                                    selectedEmployee!, selectedLeaveTypeId!);
                              }
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

                // Leave Type Dropdown
                DropdownButtonFormField<String>(
                  isExpanded: true, // Ensures the dropdown takes full width
                  decoration: InputDecoration(
                    labelText: 'Leave Type',
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(15), // Rounded corners
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  value: selectedLeaveTypeId,
                  onChanged: (newValue) {
                    if (newValue != null) {
                      String leaveName = leaveTypeList.firstWhere(
                          (type) => type['id'] == newValue)['name']!;
                      setState(() {
                        selectedLeaveTypeId = newValue;
                        selectedLeaveTypeName = leaveName;
                        showLeaveStatus = false;
                        leaveStatus = {};
                        simplifiedLeaveStatus = {};
                      });
                      if (selectedEmployee != null) {
                        fetchLeaveStatus(
                            selectedEmployee!, selectedLeaveTypeId!);
                      }
                      // Fetch Document Codes when Leave Type is selected
                      fetchDocumentCodes();
                    }
                  },
                  validator: (value) =>
                      value == null ? 'Please select a leave type' : null,
                  items: leaveTypeList.map((leaveType) {
                    return DropdownMenuItem(
                      value: leaveType['id'],
                      child: Text(leaveType['name']!),
                    );
                  }).toList(),
                ),
                SizedBox(height: 16),

                // Leave Status Title with Eye Icon
                if (selectedEmployee != null && selectedLeaveTypeId != null)
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
                                      initialValue:
                                          entry.value.toString() ?? 'N/A',
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

                // Leave Nature Dropdown
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Leave Nature',
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(15), // Rounded corners
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  value: selectedLeaveNature,
                  onChanged: (newValue) {
                    setState(() {
                      selectedLeaveNature = newValue;
                    });
                  },
                  validator: (value) =>
                      value == null ? 'Please select leave nature' : null,
                  items: ['Full Day', 'First Half', 'Second Half']
                      .map((leaveNature) {
                    return DropdownMenuItem(
                      value: leaveNature,
                      child: Text(leaveNature),
                    );
                  }).toList(),
                ),
                SizedBox(height: 16),

                // Start Date Picker
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

                // End Date Picker
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
                    DateTime initialDate = endDate ?? startDate!;
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

                // Replacement Employee Dropdown
                DropdownButtonFormField<String>(
                  isExpanded: true, // Ensures the dropdown takes full width
                  decoration: InputDecoration(
                    labelText: 'Replacement Employee',
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(15), // Rounded corners
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  value: selectedReplacementEmployee,
                  onChanged: (newValue) {
                    setState(() {
                      selectedReplacementEmployee = newValue;
                    });
                  },
                  validator: (value) => value == null
                      ? 'Please select a replacement employee'
                      : null,
                  items: filteredReplacementEmployees.map((employee) {
                    return DropdownMenuItem(
                      value: employee['id'],
                      child: Text(employee['name']!),
                    );
                  }).toList(),
                ),
                SizedBox(height: 16),

                // Reason for Leave
                TextFormField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText: 'Reason for Leave',
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
                        initialValue: pending,
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
                        : Text('Submit Leave Request'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Example function to submit leave request (API 4)
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
          "LEAVE_TYPE_ID": selectedLeaveTypeId!, // From dropdown selection
          "LEAVE_TYPE_SETUP_CODE":
              leaveTypeSetupCode ?? "HLT003", // From fetched employee details
          "LEAVE_NATURE": mapLeaveNatureToString(
              selectedLeaveNature), // Mapped from dropdown selection
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
          "REPLACE_EMP_ID":
              selectedReplacementEmployee ?? "", // From dropdown selection
          "EX_COUNTRY_ID": "", // Static value as per model
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
        print('Submitting Leave Request: ${json.encode(leaveRequest)}');

        final response = await http.post(
          Uri.parse(
              'https://api.teckmech.com:8083/api/LeaveRequest/CreateLeaveRequest'),
          headers: headers,
          body: json.encode(leaveRequest),
        );

        print(
            'Submit Leave Request API Response Status: ${response.statusCode}');
        print('Submit Leave Request API Response Body: ${response.body}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          // Handle success
          print('Leave request submitted successfully.');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Leave request submitted successfully')),
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
            leaveType: selectedLeaveTypeName ?? "N/A",
            startDate: startDate ?? DateTime.now(),
            endDate: endDate ?? DateTime.now(),
            leaveNature: selectedLeaveNature ?? "Full Day",
            status: "Pending",
          );

          // Save the leave request locally
          await saveLeaveRequest(newLeave);

          // Clear the form
          _formKey.currentState!.reset();
          setState(() {
            selectedEmployee = null;
            selectedLeaveTypeId = '1'; // Reset to 'Annual Leave'
            selectedLeaveTypeName = 'Annual Leave';
            selectedLeaveNature = 'Full Day'; // Reset to 'Full Day'
            selectedReplacementEmployee = null;
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
              'Failed to submit leave request: ${responseBody['Message'] ?? 'Unknown error'}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Failed to submit leave request: ${responseBody['Message'] ?? 'Unknown error'}')),
          );
        }
      } catch (e) {
        print('Error submitting leave request: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error submitting leave request: ${e.toString()}')),
        );
      } finally {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }
}

class LeaveHistoryPage extends StatefulWidget {
  const LeaveHistoryPage({super.key});

  @override
  _LeaveHistoryPageState createState() => _LeaveHistoryPageState();
}

class _LeaveHistoryPageState extends State<LeaveHistoryPage> {
  List<LeaveRequest> leaveHistory = [];
  bool isLoading = true;
  final storage = FlutterSecureStorage();
  late AuthService authService;
  String? username;

  @override
  void initState() {
    super.initState();
    authService = AuthService(storage: storage);
    fetchLeaveHistory();
    fetchUsername();
  }

  /// Fetches the username from secure storage.
  Future<void> fetchUsername() async {
    try {
      String fetchedUsername = await authService.getUsername();
      setState(() {
        username = fetchedUsername;
      });
      print('Fetched username: $username');
    } catch (e) {
      print('Error fetching username: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching username: ${e.toString()}')),
      );
    }
  }

  /// Fetches the leave history from local storage.
  Future<void> fetchLeaveHistory() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> leaveList = prefs.getStringList('leaveHistory') ?? [];

      setState(() {
        leaveHistory = leaveList
            .map((leaveJson) => LeaveRequest.fromJson(json.decode(leaveJson)))
            .toList();
        isLoading = false;
      });
      print('Fetched ${leaveHistory.length} leave requests locally.');
    } catch (e) {
      print('Error fetching leave history: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error fetching leave history: ${e.toString()}')),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Clears all leave history from local storage
  Future<void> clearLeaveHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('leaveHistory');
    setState(() {
      leaveHistory.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Leave history cleared successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Leave History'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            tooltip: 'Clear Leave History',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Clear Leave History'),
                  content:
                      Text('Are you sure you want to clear all leave history?'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                      },
                      child: Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        clearLeaveHistory();
                        Navigator.of(ctx).pop();
                      },
                      child: Text(
                        'Clear',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : leaveHistory.isEmpty
              ? Center(
                  child: Text(
                    'No leave history available.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView.builder(
                    itemCount: leaveHistory.length,
                    itemBuilder: (context, index) {
                      final leave = leaveHistory[index];
                      return Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        margin:
                            EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.shade50,
                                Colors.green.shade100
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header Row
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Leave Type: ${leave.leaveType}',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade800),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Chip(
                                    label: Text(
                                      leave.status,
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    backgroundColor: leave.status == 'Approved'
                                        ? Colors.green
                                        : leave.status == 'Pending'
                                            ? Colors.orange
                                            : Colors.red,
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),
                              // Details
                              Row(
                                children: [
                                  Icon(Icons.person, color: Colors.grey[700]),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'User ID: ${leave.userId}',
                                      style: TextStyle(fontSize: 16),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 5),
                              Row(
                                children: [
                                  Icon(Icons.badge, color: Colors.grey[700]),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Emp ID: ${leave.empId}',
                                      style: TextStyle(fontSize: 16),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 5),
                              Row(
                                children: [
                                  Icon(Icons.person_outline,
                                      color: Colors.grey[700]),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      // Changed from employeeName to username
                                      'Username: ${username ?? 'N/A'}',
                                      style: TextStyle(fontSize: 16),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 5),
                              Row(
                                children: [
                                  Icon(Icons.note, color: Colors.grey[700]),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Draft No: ${leave.draftNumber}',
                                      style: TextStyle(fontSize: 16),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 5),
                              Row(
                                children: [
                                  Icon(Icons.document_scanner,
                                      color: Colors.grey[700]),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Doc No: ${leave.documentNumber}',
                                      style: TextStyle(fontSize: 16),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),
                              Divider(),
                              SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(Icons.date_range,
                                      color: Colors.grey[700]),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'From: ${DateFormat('dd/MM/yyyy').format(leave.startDate)}',
                                      style: TextStyle(fontSize: 16),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 5),
                              Row(
                                children: [
                                  Icon(Icons.date_range,
                                      color: Colors.grey[700]),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'To: ${DateFormat('dd/MM/yyyy').format(leave.endDate)}',
                                      style: TextStyle(fontSize: 16),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 5),
                              Row(
                                children: [
                                  Icon(Icons.nature_people,
                                      color: Colors.grey[700]),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Nature: ${leave.leaveNature}',
                                      style: TextStyle(fontSize: 16),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

void main() => runApp(MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // Updated text theme
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: Colors.black),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.green,
        ),
      ),
      home: LeavesPage(),
    ));
