// complaint_history_page.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

// Import the EditComplaintPage
import 'edit_complaint_page.dart';

class ComplaintHistoryPage extends StatefulWidget {
  const ComplaintHistoryPage({super.key});

  @override
  _ComplaintHistoryPageState createState() => _ComplaintHistoryPageState();
}

class _ComplaintHistoryPageState extends State<ComplaintHistoryPage> {
  final _storage = const FlutterSecureStorage();
  final _logger = Logger();
  List<dynamic> _complaintData = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchComplaintHistory();
  }

  Future<void> _fetchComplaintHistory() async {
    try {
      final userId = await _storage.read(key: 'userId') ?? '57';
      final userName = await _storage.read(key: 'userName') ?? 'admin';
      final accessToken = await _storage.read(key: 'accessToken') ?? '';

      const url =
          'https://api.teckmech.com:8083/api/Complaint/ComplaintListing';

      final body = jsonEncode({
        "draw": 2,
        "columns": [
          {
            "data": null,
            "name": "",
            "searchable": false,
            "orderable": false,
            "search": {"value": "", "regex": false}
          },
          {
            "data": "COMPLAINTKPI_ID",
            "name": "",
            "searchable": true,
            "orderable": true,
            "search": {"value": "", "regex": false}
          },
          {
            "data": null,
            "name": "",
            "searchable": false,
            "orderable": false,
            "search": {"value": "", "regex": false}
          },
          {
            "data": "DOC_DATE",
            "name": "",
            "searchable": true,
            "orderable": true,
            "search": {"value": "", "regex": false}
          },
          {
            "data": "TITLE",
            "name": "",
            "searchable": true,
            "orderable": true,
            "search": {"value": "", "regex": false}
          },
          {
            "data": "EMP_NAME",
            "name": "",
            "searchable": true,
            "orderable": true,
            "search": {"value": "", "regex": false}
          },
          {
            "data": "DOC_DRAFT_NO",
            "name": "",
            "searchable": true,
            "orderable": true,
            "search": {"value": "", "regex": false}
          },
          {
            "data": "DOC_NO",
            "name": "",
            "searchable": true,
            "orderable": true,
            "search": {"value": "", "regex": false}
          },
          {
            "data": "DOC_STATUS",
            "name": "",
            "searchable": true,
            "orderable": true,
            "search": {"value": "", "regex": false}
          },
          {
            "data": "CONTACT_NO",
            "name": "",
            "searchable": true,
            "orderable": true,
            "search": {"value": "", "regex": false}
          },
          {
            "data": "STATUS",
            "name": "",
            "searchable": true,
            "orderable": true,
            "search": {"value": "", "regex": false}
          }
        ],
        "order": [
          {"column": 3, "dir": "asc"}
        ],
        "start": 0,
        "length": 10,
        "search": {"value": "", "regex": false},
        "searchcriteria": [
          {
            "ColumnName": "KPI.CO_BRANCH_ID",
            "Operation": "0",
            "SEARCH_CRITERIA_ID": "12190",
            "param1": "1,2,21,22"
          }
        ],
        "LicAccountNo": 1,
        "CompanyId": 1,
        "UserName": userName,
        "DepartmentId": 0,
        "UserDepartments": null,
        "DOC_ID": "",
        "userId": int.parse(userId),
        "DocTypeId": 356
      });

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      _logger.i('API Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('data')) {
          setState(() {
            _complaintData = data['data'] ?? [];
            _isLoading = false;
          });
        } else {
          throw Exception('Unexpected API response format');
        }
      } else {
        // Attempt to extract error message from response
        String errorMessage = 'Failed to fetch data: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map<String, dynamic> &&
              errorData.containsKey('message')) {
            errorMessage = errorData['message'];
          }
        } catch (_) {
          // If response is not JSON or doesn't contain 'message', retain the default error message
        }
        _logger.e(errorMessage);
        setState(() {
          _isLoading = false;
        });
        // Inform the user about the error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e, stackTrace) {
      // Log the error with stack trace for better debugging
      _logger.e('Error occurred: $e');
      _logger.e('Stack Trace: $stackTrace');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load complaint history. Please try again.';
      });
      // Inform the user about the error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
    }
  }

  /// SHOW FULL HISTORY WITH MULTIPLE RECORDS
  /// + THUMBNAIL IMAGE + DIALOG WITH LARGER IMAGE
  Future<void> _showComplaintDetails(int complaintId) async {
    try {
      final accessToken = await _storage.read(key: 'accessToken') ?? '';
      final url =
          'https://api.teckmech.com:8083/api/Complaint/LoadComplaintHistory?BranchId=1&CompId=1&Id=$complaintId';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      _logger.i('Detail API Response: ${response.body}');

      if (response.statusCode == 200) {
        // Parse ALL records (list of maps)
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text(
                  'Complaint Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final complaint = data[index];
                      // Determine if this is the last record
                      final isLast = index == data.length - 1;

                      // Construct the image URL (if any)
                      final baseUrl = 'https://api.teckmech.com:8083';
                      final attachDocId =
                          complaint['REF_ATTACH_DOC_ID']?.toString() ?? '';
                      final imageUrl = attachDocId.isNotEmpty
                          ? '$baseUrl$attachDocId'
                          : null;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Complaint Information
                          const Text(
                            'Complaint Information',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 10),
                          Text(
                              'Title: ${complaint['COMPLAINT_NAME'] ?? 'N/A'}'),
                          Text(
                              'Resolver: ${complaint['RESOLVER_NAME'] ?? 'N/A'}'),
                          Text(
                              'Mobile: ${complaint['MOBILE_NUMBER'] ?? 'N/A'}'),
                          Text(
                              'Created By: ${complaint['CREATED_BY'] ?? 'N/A'}'),
                          Text(
                              'Modified By: ${complaint['MODIFY_BY'] ?? 'N/A'}'),
                          Text(
                            'Complaint Status: '
                            '${(complaint['STATUS'] ?? '1') == '2' ? 'Resolved' : 'Open'}',
                          ),
                          Text('Location: ${complaint['LOCATION'] ?? 'N/A'}'),
                          Text(
                              'Description: ${complaint['DESCRIPTION'] ?? 'N/A'}'),
                          const SizedBox(height: 20),

                          // Document detail
                          const Text(
                            'Document Detail',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 10),
                          Text(
                              'Draft Number: ${complaint['DOC_DRAFT_NO'] ?? 'N/A'}'),
                          Text('Document Status: Draft'), // Adjust if needed
                          Text(
                              'Document Date: ${complaint['DOC_DATE'] ?? 'N/A'}'),
                          Text('Branch: ${complaint['BRANCH_NAME'] ?? 'N/A'}'),
                          Text(
                              'Department: ${complaint['DEPT_NAME'] ?? 'N/A'}'),
                          const SizedBox(height: 10),

                          // Show a small thumbnail if imageUrl is valid
                          if (imageUrl != null && imageUrl.isNotEmpty) ...[
                            const Text(
                              'Attachment:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 5),
                            GestureDetector(
                              onTap: () => _showImageDialog(imageUrl),
                              child: Image.network(
                                imageUrl,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Text(
                                    'Failed to load image.',
                                    style: TextStyle(color: Colors.red),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // EDIT button only on the last record
                          if (isLast)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  // Close the dialog
                                  Navigator.of(context).pop();
                                  // Navigate to EditComplaintPage with this record
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => EditComplaintPage(
                                        complaintData: complaint,
                                      ),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Edit',
                                  style: TextStyle(color: Colors.blue),
                                ),
                              ),
                            ),

                          // Divider between records
                          if (!isLast)
                            const Divider(
                              thickness: 2,
                            ),
                        ],
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              );
            },
          );
        } else {
          _logger.e('No complaint details found.');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No complaint details found.')),
          );
        }
      } else {
        throw Exception('Failed to fetch details: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Error occurred: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load complaint details.')),
      );
    }
  }

  /// Shows the image in a larger dialog when thumbnail is tapped
  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: InteractiveViewer(
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Failed to load image.',
                    style: TextStyle(color: Colors.red),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaint History'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFB2FEFA), Color(0xFF0ED2F7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 18, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                )
              : _complaintData.isEmpty
                  ? const Center(
                      child: Text(
                        'No complaint history available.',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _complaintData.length,
                      itemBuilder: (context, index) {
                        final complaint = _complaintData[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15.0, vertical: 10.0),
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            elevation: 4,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFF9F9F9),
                                    Color(0xFFEEF2F3)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius:
                                    BorderRadius.all(Radius.circular(20.0)),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(20.0),
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0xFFEEF2F3),
                                  child: Icon(
                                    Icons.assignment,
                                    color: Colors.blueGrey,
                                  ),
                                ),
                                title: Text(
                                  complaint['TITLE'] ?? 'No Title',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.black87,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        const Icon(Icons.date_range,
                                            size: 16, color: Colors.blueGrey),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            'Date: ${complaint['DOC_DATE'] ?? 'N/A'}',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.black54),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        const Icon(Icons.check_circle,
                                            size: 16, color: Colors.blueGrey),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            'Status: ${complaint['DOC_STATUS'] ?? 'N/A'}',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.black54),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone,
                                            size: 16, color: Colors.blueGrey),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            'Contact: ${complaint['CONTACT_NO'] ?? 'N/A'}',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.black54),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.blueGrey,
                                ),
                                onTap: () => _showComplaintDetails(
                                    complaint['COMPLAINTKPI_ID']),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );

    void navigateToEditPage(int complaintId) {
      // TODO: Implement navigation to the Edit Complaint page if needed
      _logger.i('Navigate to edit page for complaint ID: $complaintId');
      // Placeholder implementation
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Edit functionality is not implemented yet.')),
      );
    }
  }
}
