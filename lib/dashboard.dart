// ignore_for_file: sort_child_properties_last

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'api_service.dart'; // Added import for ApiService

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final storage = const FlutterSecureStorage(); // Made storage constant
  late Future<List<PieChartData>> _chartData;
  late Future<List<DesignationData>> _designationData;
  late Future<List<EmployeeStatusData>> _employeeStatusData;
  late Future<List<AgeDistributionData>> _ageDistributionData;

  // New Future for UC Wise Attendance Data
  late Future<List<UcWiseAttendanceData>> _ucChartData;

  // Filter variables
  String selectedDateOperation = "10"; // Default to Today
  String selectedDepartment = "Maintenance Department"; // Default Department
  String selectedBranch = "Faisalabad"; // Default Branch

  // Display variable
  String currentDepartmentName =
      "Maintenance Department"; // To display as heading

  @override
  void initState() {
    super.initState();
    _chartData = fetchInitialChartData();
    _designationData = fetchDesignationData();
    _employeeStatusData = fetchEmployeeStatusData();
    _ageDistributionData = fetchAgeDistributionData();
    _ucChartData = fetchUcWiseAttendanceData(); // Initialize UC Chart Data
  }

  // Function to retrieve accessToken from secure storage
  Future<String?> getAccessToken() async {
    String? token = await storage.read(key: 'accessToken');
    debugPrint('Retrieved Access Token: $token');
    return token;
  }

  // Generic fetch method to reduce code duplication
  Future<List<T>> fetchChartData<T>(
      String url, T Function(Map<String, dynamic>) fromJson) async {
    final token = await getAccessToken();

    if (token == null) {
      throw Exception('Access token is null. Please log in again.');
    }

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization':
              'Bearer $token', // Ensure authorization header is set
          'Content-Type': 'application/json', // Added content-type header
        },
      );

      debugPrint('API Response: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.isEmpty || data[0].isEmpty) {
          throw Exception('No data received from API.');
        }
        return (data[0] as List)
            .map<T>((item) => fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      debugPrint('Exception: $e');
      throw Exception('Failed to load data');
    }
  }

  // Fetch initial pie chart data based on default filters
  Future<List<PieChartData>> fetchInitialChartData() async {
    String baseUrl = ApiService.getBaseUrl(); // Fetch dynamic base URL
    final url =
        '$baseUrl/api/Chart/DrawChartsDynamically?currentSelectedGraphID=ChartReport_3062&CompId=1&User_ID=57&DateFormat=dd/mm/yyyy';
    return fetchChartData<PieChartData>(
        url,
        (json) => PieChartData(
              json['name'] ?? 'Unknown',
              (json['y'] ?? 0).toDouble(),
            ));
  }

  // Fetch designation data
  Future<List<DesignationData>> fetchDesignationData() async {
    String baseUrl = ApiService.getBaseUrl(); // Fetch dynamic base URL
    final url =
        '$baseUrl/api/Chart/DrawChartsDynamically?currentSelectedGraphID=ChartReport_2142&CompId=1&User_ID=57&DateFormat=dd/mm/yyyy';
    return fetchChartData<DesignationData>(
        url,
        (json) => DesignationData(
              designation: json['name'] ?? 'Unknown',
              employeeCount: (json['y'] ?? 0).toDouble(),
            ));
  }

  // Fetch employee status data
  Future<List<EmployeeStatusData>> fetchEmployeeStatusData() async {
    String baseUrl = ApiService.getBaseUrl(); // Fetch dynamic base URL
    final url =
        '$baseUrl/api/Chart/DrawChartsDynamically?currentSelectedGraphID=ChartReport_2143&CompId=1&User_ID=57&DateFormat=dd/mm/yyyy';
    return fetchChartData<EmployeeStatusData>(
        url,
        (json) => EmployeeStatusData(
              status: json['name'] ?? 'Unknown',
              count: (json['y'] ?? 0).toDouble(),
            ));
  }

  // Fetch age distribution data
  Future<List<AgeDistributionData>> fetchAgeDistributionData() async {
    String baseUrl = ApiService.getBaseUrl(); // Fetch dynamic base URL
    final url =
        '$baseUrl/api/Chart/DrawChartsDynamically?currentSelectedGraphID=ChartReport_2144&CompId=1&User_ID=57&DateFormat=dd/mm/yyyy';
    return fetchChartData<AgeDistributionData>(
        url,
        (json) => AgeDistributionData(
              ageRange: json['name'] ?? 'Unknown',
              count: (json['y'] ?? 0).toDouble(),
            ));
  }

  // New fetch method for UC Wise Attendance Data
  Future<List<UcWiseAttendanceData>> fetchUcWiseAttendanceData() async {
    String baseUrl = ApiService.getBaseUrl(); // Fetch dynamic base URL
    final url =
        '$baseUrl/api/Chart/DrawChartsDynamically?currentSelectedGraphID=ChartReport_7282&CompId=1&User_ID=57&DateFormat=dd/mm/yyyy';
    return fetchChartData<UcWiseAttendanceData>(
        url,
        (json) => UcWiseAttendanceData(
              id: json['ID'] ?? '',
              ucName: json['name'] ?? 'Unknown UC',
              seriesName: json['SERIES_NAME'] ?? 'Unknown Status',
              count: (json['y'] ?? 0).toDouble(),
            ));
  }

  // Fetch filtered chart data based on selected filters
  Future<List<PieChartData>> fetchFilteredChartData() async {
    if (selectedDepartment != "Maintenance Department") {
      return [];
    }

    final token = await getAccessToken();

    if (token == null) {
      throw Exception('Access token is null. Please log in again.');
    }

    String baseUrl = ApiService.getBaseUrl(); // Fetch dynamic base URL
    final url = Uri.parse(
      '$baseUrl/api/HRM/Dashboard/GetDeptAttnFilterV1?CompID=1&UserID=57&DateFormat=dd/mm/yyyy',
    );

    final body = [
      {
        "SEARCH_CRITERIA_ID": "6089",
        "Operation": selectedDateOperation,
        "ColumnName": "MUS.ATTN_DATE_TIME",
        "param1": selectedDepartment,
        "param2": selectedBranch,
        "param3": "",
        "param4": ""
      }
    ];

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.isEmpty) {
          throw Exception('No data received from API.');
        }

        final deptData = data[0];

        setState(() {
          currentDepartmentName = deptData['DEPT_NAME'] ?? 'Unknown Department';
        });

        List<PieChartData> chartData = [];
        Map<String, dynamic> categories = {
          "In Time": deptData['IN_TIME'] ?? 0,
          "Late": deptData['LATE'] ?? 0,
          "Absent": deptData['ABSENT'] ?? 0,
          "Holiday": deptData['HOLIDAY'] ?? 0,
          "Rest": deptData['REST'] ?? 0,
          "Not Working": deptData['NOT_WORKING'] ?? 0,
          "Leave": deptData['LEAVE'] ?? 0,
        };

        categories.forEach((key, value) {
          if (value > 0) {
            chartData.add(PieChartData(key, (value).toDouble()));
          }
        });

        return chartData;
      } else {
        throw Exception('Failed to load filtered chart data');
      }
    } catch (e) {
      debugPrint('Exception: $e');
      throw Exception('Failed to load filtered chart data');
    }
  }

  // Function to open the search/filter dialog
  void _openSearchDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String tempDateOperation = selectedDateOperation;
        String tempDepartment = selectedDepartment;
        String tempBranch = selectedBranch;

        return AlertDialog(
          title: Text(
            'Filter Data',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: tempDateOperation,
                      items: [
                        DropdownMenuItem(value: "10", child: Text("Today")),
                        DropdownMenuItem(value: "11", child: Text("Yesterday")),
                        DropdownMenuItem(value: "12", child: Text("This Week")),
                        DropdownMenuItem(
                            value: "13", child: Text("This Month")),
                        DropdownMenuItem(value: "14", child: Text("This Year")),
                        DropdownMenuItem(value: "15", child: Text("Last Week")),
                        DropdownMenuItem(
                            value: "16", child: Text("Last Month")),
                        DropdownMenuItem(value: "17", child: Text("Is Empty")),
                        DropdownMenuItem(
                            value: "18", child: Text("Is Not Empty")),
                        DropdownMenuItem(
                            value: "38", child: Text("Current Financial Year")),
                        DropdownMenuItem(
                            value: "39", child: Text("Between Months")),
                        DropdownMenuItem(
                            value: "4", child: Text("In the Last")),
                        DropdownMenuItem(value: "5", child: Text("Due In")),
                        DropdownMenuItem(value: "6", child: Text("On")),
                        DropdownMenuItem(value: "7", child: Text("Before")),
                        DropdownMenuItem(value: "8", child: Text("After")),
                        DropdownMenuItem(value: "9", child: Text("Between")),
                      ],
                      onChanged: (value) {
                        setState(() {
                          tempDateOperation = value!;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Date Operation',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: tempDepartment,
                      items: [
                        DropdownMenuItem(
                            value: "Administration",
                            child: Text("Administration")),
                        DropdownMenuItem(
                            value: "Maintenance Department",
                            child: Text("Maintenance Department")),
                        DropdownMenuItem(
                            value: "Head Office", child: Text("Head Office")),
                      ],
                      onChanged: (value) {
                        setState(() {
                          tempDepartment = value!;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Department',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: tempBranch,
                      items: [
                        DropdownMenuItem(
                            value: "Faisalabad", child: Text("Faisalabad")),
                        DropdownMenuItem(
                            value: "Lahore", child: Text("Lahore")),
                        DropdownMenuItem(
                            value: "Karachi", child: Text("Karachi")),
                        // Add more branches as needed
                      ],
                      onChanged: (value) {
                        setState(() {
                          tempBranch = value!;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Branch',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  selectedDateOperation = tempDateOperation;
                  selectedDepartment = tempDepartment;
                  selectedBranch = tempBranch;
                  _chartData = fetchFilteredChartData();
                  _designationData = fetchDesignationData();
                  _employeeStatusData = fetchEmployeeStatusData();
                  _ageDistributionData = fetchAgeDistributionData();
                  _ucChartData =
                      fetchUcWiseAttendanceData(); // Refetch UC Chart Data
                });
              },
              child: Text('Apply'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Define distinct color schemes for each chart
    final Color primaryColor = const Color.fromARGB(255, 196, 143, 46);
    final Color pieChartColor = Colors.deepPurple;
    final Color designationChartColor = Colors.teal;
    final Color employeeStatusChartColor = Colors.orange;
    final Color ageDistributionChartColor = Colors.green;
    final Color ucAttendanceChartColor = Colors.blueAccent; // New Color

    return Scaffold(
        appBar: AppBar(
          title: Text(
            'Dashboard',
            style: GoogleFonts.lato(
              textStyle: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          backgroundColor: primaryColor,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                setState(() {
                  _chartData = fetchInitialChartData();
                  _designationData = fetchDesignationData();
                  _employeeStatusData = fetchEmployeeStatusData();
                  _ageDistributionData = fetchAgeDistributionData();
                  _ucChartData =
                      fetchUcWiseAttendanceData(); // Refresh UC Chart Data
                });
              },
              tooltip: 'Refresh Data',
            ),
          ],
        ),
        body: Container(
          color: Colors.grey[50], // Light background color
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Header Row with Title and Filter Icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Department Wise Attendance',
                      style: GoogleFonts.lato(
                        textStyle: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.filter_list, color: primaryColor),
                      onPressed: _openSearchDialog,
                      tooltip: 'Filter Data',
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Divider(thickness: 1.5, color: Colors.grey[300]),
                SizedBox(height: 10),
                // Current Department Name
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    currentDepartmentName,
                    style: GoogleFonts.lato(
                      textStyle: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                // Expanded Section for Charts
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Attendance Overview Chart
                        ChartCard(
                          title: 'Attendance Overview',
                          child: FutureBuilder<List<PieChartData>>(
                            future: _chartData,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                    child: CircularProgressIndicator());
                              } else if (snapshot.hasError) {
                                return ErrorSection(
                                  message: 'Error: ${snapshot.error}',
                                  onRetry: () {
                                    setState(() {
                                      _chartData = fetchFilteredChartData();
                                    });
                                  },
                                );
                              } else if (!snapshot.hasData ||
                                  snapshot.data!.isEmpty) {
                                return NoDataSection(
                                    message: 'No data available');
                              } else {
                                return SfCircularChart(
                                  legend: Legend(
                                    isVisible: true,
                                    overflowMode: LegendItemOverflowMode.wrap,
                                    textStyle: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  tooltipBehavior:
                                      TooltipBehavior(enable: true),
                                  series: <PieSeries<PieChartData, String>>[
                                    PieSeries<PieChartData, String>(
                                      dataSource: snapshot.data!,
                                      xValueMapper: (PieChartData data, _) =>
                                          data.category,
                                      yValueMapper: (PieChartData data, _) =>
                                          data.value,
                                      dataLabelSettings: DataLabelSettings(
                                        isVisible: true,
                                        labelPosition:
                                            ChartDataLabelPosition.outside,
                                        textStyle: TextStyle(
                                          fontSize: 12,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      pointColorMapper:
                                          (PieChartData data, _) =>
                                              getCategoryColor(data.category),
                                      enableTooltip: true,
                                    ),
                                  ],
                                );
                              }
                            },
                          ),
                          color: pieChartColor,
                        ),
                        SizedBox(height: 20),

                        // Employee Count by Designation Chart
                        ChartCard(
                          title: 'Employee Count by Designation',
                          child: FutureBuilder<List<DesignationData>>(
                            future: _designationData,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                    child: CircularProgressIndicator());
                              } else if (snapshot.hasError) {
                                return ErrorSection(
                                  message: 'Error: ${snapshot.error}',
                                  onRetry: () {
                                    setState(() {
                                      _designationData = fetchDesignationData();
                                    });
                                  },
                                );
                              } else if (!snapshot.hasData ||
                                  snapshot.data!.isEmpty) {
                                return NoDataSection(
                                    message: 'No designation data available');
                              } else {
                                return SfCartesianChart(
                                  primaryXAxis: CategoryAxis(
                                    labelRotation: 45,
                                    majorGridLines: MajorGridLines(width: 0),
                                    labelStyle: TextStyle(
                                      color: Colors.black87,
                                    ),
                                  ),
                                  primaryYAxis: NumericAxis(
                                    title: AxisTitle(
                                      text: 'Number of Employees',
                                      textStyle: TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    labelFormat: '{value}',
                                    majorGridLines: MajorGridLines(width: 0.5),
                                    labelStyle: TextStyle(
                                      color: Colors.black87,
                                    ),
                                  ),
                                  tooltipBehavior:
                                      TooltipBehavior(enable: true),
                                  series: <ColumnSeries<DesignationData,
                                      String>>[
                                    ColumnSeries<DesignationData, String>(
                                      dataSource: snapshot.data!,
                                      xValueMapper: (DesignationData data, _) =>
                                          data.designation,
                                      yValueMapper: (DesignationData data, _) =>
                                          data.employeeCount,
                                      name: 'Employees',
                                      dataLabelSettings: DataLabelSettings(
                                        isVisible: true,
                                        textStyle: TextStyle(
                                          color: Colors.black87,
                                        ),
                                      ),
                                      color: designationChartColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ],
                                );
                              }
                            },
                          ),
                          color: designationChartColor,
                        ),
                        SizedBox(height: 20),

                        // Employee Status Chart
                        ChartCard(
                          title: 'Employee Status',
                          child: FutureBuilder<List<EmployeeStatusData>>(
                            future: _employeeStatusData,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                    child: CircularProgressIndicator());
                              } else if (snapshot.hasError) {
                                return ErrorSection(
                                  message: 'Error: ${snapshot.error}',
                                  onRetry: () {
                                    setState(() {
                                      _employeeStatusData =
                                          fetchEmployeeStatusData();
                                    });
                                  },
                                );
                              } else if (!snapshot.hasData ||
                                  snapshot.data!.isEmpty) {
                                return NoDataSection(
                                    message:
                                        'No employee status data available');
                              } else {
                                return SfCartesianChart(
                                  primaryXAxis: CategoryAxis(
                                    labelStyle: TextStyle(
                                      color: Colors.black87,
                                    ),
                                  ),
                                  primaryYAxis: NumericAxis(
                                    title: AxisTitle(
                                      text: 'Number of Employees',
                                      textStyle: TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    labelFormat: '{value}',
                                    majorGridLines: MajorGridLines(width: 0.5),
                                    labelStyle: TextStyle(
                                      color: Colors.black87,
                                    ),
                                  ),
                                  tooltipBehavior:
                                      TooltipBehavior(enable: true),
                                  series: <BarSeries<EmployeeStatusData,
                                      String>>[
                                    BarSeries<EmployeeStatusData, String>(
                                      dataSource: snapshot.data!,
                                      xValueMapper:
                                          (EmployeeStatusData data, _) =>
                                              data.status,
                                      yValueMapper:
                                          (EmployeeStatusData data, _) =>
                                              data.count,
                                      name: 'Status',
                                      dataLabelSettings: DataLabelSettings(
                                        isVisible: true,
                                        textStyle: TextStyle(
                                          color: Colors.black87,
                                        ),
                                      ),
                                      color: employeeStatusChartColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ],
                                );
                              }
                            },
                          ),
                          color: employeeStatusChartColor,
                        ),
                        SizedBox(height: 20),

                        // Age Distribution Chart
                        ChartCard(
                          title: 'Age Distribution',
                          child: FutureBuilder<List<AgeDistributionData>>(
                            future: _ageDistributionData,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                    child: CircularProgressIndicator());
                              } else if (snapshot.hasError) {
                                return ErrorSection(
                                  message: 'Error: ${snapshot.error}',
                                  onRetry: () {
                                    setState(() {
                                      _ageDistributionData =
                                          fetchAgeDistributionData();
                                    });
                                  },
                                );
                              } else if (!snapshot.hasData ||
                                  snapshot.data!.isEmpty) {
                                return NoDataSection(
                                    message:
                                        'No age distribution data available');
                              } else {
                                return SfCartesianChart(
                                  primaryXAxis: CategoryAxis(
                                    title: AxisTitle(
                                      text: 'Age Range',
                                      textStyle: TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    labelRotation: 45,
                                    majorGridLines: MajorGridLines(width: 0),
                                    labelStyle: TextStyle(
                                      color: Colors.black87,
                                    ),
                                  ),
                                  primaryYAxis: NumericAxis(
                                    title: AxisTitle(
                                      text: 'Number of Employees',
                                      textStyle: TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    labelFormat: '{value}',
                                    majorGridLines: MajorGridLines(width: 0.5),
                                    labelStyle: TextStyle(
                                      color: Colors.black87,
                                    ),
                                  ),
                                  tooltipBehavior:
                                      TooltipBehavior(enable: true),
                                  series: <StackedAreaSeries<
                                      AgeDistributionData, String>>[
                                    StackedAreaSeries<AgeDistributionData,
                                        String>(
                                      dataSource: snapshot.data!,
                                      xValueMapper:
                                          (AgeDistributionData data, _) =>
                                              data.ageRange,
                                      yValueMapper:
                                          (AgeDistributionData data, _) =>
                                              data.count,
                                      name: 'Employees',
                                      dataLabelSettings: DataLabelSettings(
                                        isVisible: true,
                                        textStyle: TextStyle(
                                          color: Colors.black87,
                                        ),
                                      ),
                                      color: ageDistributionChartColor,
                                      borderColor:
                                          ageDistributionChartColor.shade700,
                                      borderWidth: 2,
                                    ),
                                  ],
                                );
                              }
                            },
                          ),
                          color: ageDistributionChartColor,
                        ),
                        SizedBox(height: 20),

                        // New UC Wise Attendance Chart with Optimized Layout
                        ChartCard(
                          title: 'UC Wise Attendance',
                          child: FutureBuilder<List<UcWiseAttendanceData>>(
                            future: _ucChartData,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                    child: CircularProgressIndicator());
                              } else if (snapshot.hasError) {
                                return ErrorSection(
                                  message: 'Error: ${snapshot.error}',
                                  onRetry: () {
                                    setState(() {
                                      _ucChartData =
                                          fetchUcWiseAttendanceData();
                                    });
                                  },
                                );
                              } else if (!snapshot.hasData ||
                                  snapshot.data!.isEmpty) {
                                return NoDataSection(
                                    message:
                                        'No UC Wise Attendance data available');
                              } else {
                                // Process data to group by seriesName (status)
                                Map<String, List<UcWiseAttendanceData>>
                                    groupedData = {};
                                for (var data in snapshot.data!) {
                                  if (!groupedData
                                      .containsKey(data.seriesName)) {
                                    groupedData[data.seriesName] = [];
                                  }
                                  groupedData[data.seriesName]!.add(data);
                                }

                                // Create a list of Series for each status
                                List<ColumnSeries<UcWiseAttendanceData, String>>
                                    seriesList = [];

                                groupedData.forEach((seriesName, dataList) {
                                  seriesList.add(ColumnSeries<
                                      UcWiseAttendanceData, String>(
                                    dataSource: dataList,
                                    xValueMapper:
                                        (UcWiseAttendanceData data, _) =>
                                            data.ucName,
                                    yValueMapper:
                                        (UcWiseAttendanceData data, _) =>
                                            data.count,
                                    name: seriesName,
                                    dataLabelSettings: DataLabelSettings(
                                      isVisible: true,
                                      textStyle: TextStyle(
                                        color: Colors.black87,
                                      ),
                                    ),
                                    color: getUcAttendanceColor(seriesName),
                                    borderRadius: BorderRadius.circular(4),
                                  ));
                                });

                                // **Minimal Change: Wrap the chart in a SizedBox with increased height**
                                return SizedBox(
                                  height: 500, // Adjust the height as needed
                                  child: SfCartesianChart(
                                    primaryXAxis: CategoryAxis(
                                      labelRotation: 45,
                                      majorGridLines:
                                          MajorGridLines(width: 0.5),
                                      labelStyle: TextStyle(
                                        color: Colors.black87,
                                      ),
                                    ),
                                    primaryYAxis: NumericAxis(
                                      title: AxisTitle(
                                        text: 'Number of Attendance',
                                        textStyle: TextStyle(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      labelFormat: '{value}',
                                      majorGridLines:
                                          MajorGridLines(width: 0.5),
                                      labelStyle: TextStyle(
                                        color: Colors.black87,
                                      ),
                                    ),
                                    legend: Legend(
                                      isVisible: true,
                                      overflowMode: LegendItemOverflowMode.wrap,
                                      textStyle: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    tooltipBehavior:
                                        TooltipBehavior(enable: true),
                                    series: seriesList,
                                  ),
                                );
                              }
                            },
                          ),
                          color: ucAttendanceChartColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
  }

  // Helper method to determine color based on attendance category
  Color getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'in time':
        return Colors.green;
      case 'late':
        return Colors.orange;
      case 'absent':
        return Colors.red;
      case 'holiday':
        return Colors.purple;
      case 'rest':
        return Colors.blue;
      case 'not working':
        return Colors.grey;
      case 'not assigned':
        return Colors.teal;
      case 'leave':
        return Colors.yellow[700]!;
      default:
        return Colors.blue;
    }
  }

  // New helper method to determine color based on UC attendance status
  Color getUcAttendanceColor(String seriesName) {
    switch (seriesName.toLowerCase()) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      case 'not assign yet':
        return Colors.orange;
      case 'assigned':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

extension on Color {
  // Added a proper implementation for shade700
  Color get shade700 {
    // Define your own shade logic or use predefined colors
    // For simplicity, returning the same color
    return this;
  }
}

// Reusable Card Widget for Charts
class ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Color color;

  const ChartCard({
    super.key,
    required this.title,
    required this.child,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white, // White background for contrast
      elevation: 6,
      shadowColor: Colors.grey.shade300,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chart Title
            Text(
              title,
              style: GoogleFonts.lato(
                textStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            SizedBox(height: 15),
            // Chart Content
            child,
          ],
        ),
      ),
    );
  }
}

// Reusable Widget for Error Sections
class ErrorSection extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorSection({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          message,
          style: TextStyle(color: Colors.redAccent, fontSize: 16),
        ),
        SizedBox(height: 10),
        ElevatedButton(
          onPressed: onRetry,
          child: Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
          ),
        ),
      ],
    );
  }
}

// Reusable Widget for No Data Sections
class NoDataSection extends StatelessWidget {
  final String message;

  const NoDataSection({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(color: Colors.grey[700], fontSize: 16),
      textAlign: TextAlign.center,
    );
  }
}

// Data Classes
class PieChartData {
  final String category;
  final double value;

  PieChartData(this.category, this.value);
}

class DesignationData {
  final String designation;
  final double employeeCount;

  DesignationData({required this.designation, required this.employeeCount});
}

class EmployeeStatusData {
  final String status;
  final double count;

  EmployeeStatusData({required this.status, required this.count});
}

class AgeDistributionData {
  final String ageRange;
  final double count;

  AgeDistributionData({required this.ageRange, required this.count});
}

// New Data Class for UC Wise Attendance
class UcWiseAttendanceData {
  final String id;
  final String ucName;
  final String seriesName;
  final double count;

  UcWiseAttendanceData({
    required this.id,
    required this.ucName,
    required this.seriesName,
    required this.count,
  });
}
