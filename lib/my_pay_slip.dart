// my_pay_slip.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart'; // Import ApiService
import 'dart:convert'; // For JSON decoding
import 'package:pdf/widgets.dart' as pw; // For PDF generation
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart'; // For PDF preview and printing
import 'package:http/http.dart' as http; // For fetching the logo image

class MyPaySlipPage extends StatefulWidget {
  const MyPaySlipPage({super.key});

  @override
  State<MyPaySlipPage> createState() => _MyPaySlipPageState();
}

class _MyPaySlipPageState extends State<MyPaySlipPage> {
  final _formKey = GlobalKey<FormState>();

  // Fetch current year
  final String currentYear = DateTime.now().year.toString();

  // List of months for the dropdown
  final List<String> months = List.generate(12, (index) {
    return DateFormat.MMMM().format(DateTime(DateTime.now().year, index + 1));
  }).reversed.toList(); // Reverse to show latest month first

  // Current month as default
  String selectedMonth = DateFormat.MMMM().format(DateTime.now());

  // Variables to hold fetched PaySlip data
  Map<String, dynamic>? paySlipData;
  bool isLoading = false;
  String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Pay Slip'),
        backgroundColor: Colors.green, // Adjust color as needed
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Input Fields Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Financial Year Field
                      _buildRoundedField(
                        label: 'Financial Year',
                        controller: TextEditingController(text: currentYear),
                        readOnly: true,
                      ),
                      const SizedBox(height: 20),
                      // Financial Year Period Field
                      _buildDropdownField(
                        label: 'Financial Year Period',
                        items: months,
                        value: selectedMonth,
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              selectedMonth = newValue;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 30),
                      // Search Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _searchPaySlip,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            backgroundColor: Colors.green, // Button color
                          ),
                          child: const Text(
                            'Search',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            // Display Loading, Error, or Pay Slip Content
            if (isLoading)
              const CircularProgressIndicator()
            else if (errorMessage != null)
              Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              )
            else if (paySlipData != null)
              _buildPaySlipCard(paySlipData!)
            else
              const Text('No pay slip data to display.'),
          ],
        ),
      ),
    );
  }

  // Method to handle Search button press
  Future<void> _searchPaySlip() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        isLoading = true;
        errorMessage = null;
        paySlipData = null;
      });

      try {
        debugPrint('Initiating pay slip fetch...');

        // Dynamically fetch the base URL using ApiService
        String baseUrl = ApiService.getBaseUrl();
        debugPrint('Base URL: $baseUrl');

        // Define the endpoint relative to the base URL with hardcoded CompId and Id
        String endpointPath =
            'api/PaySlip/ReadPaySlip?BranchId=2&CompId=1&Id=161';
        debugPrint('Endpoint Path: $endpointPath');

        // Make the POST request with an empty body as per your requirement
        Map<String, dynamic> response = await ApiService.post(endpointPath, {});

        debugPrint('PaySlip API Response: $response');

        // Print the entire response for debugging
        debugPrint('Full API Response: ${json.encode(response)}');

        // Check if the response contains 'HRM_PRL_PAY_DETAILS' and is not empty
        if (response.containsKey('HRM_PRL_PAY_DETAILS') &&
            response['HRM_PRL_PAY_DETAILS'] is List &&
            response['HRM_PRL_PAY_DETAILS'].isNotEmpty) {
          Map<String, dynamic> detail = response['HRM_PRL_PAY_DETAILS'][0];

          debugPrint('HRM_PRL_PAY_DETAILS[0]: $detail');

          setState(() {
            paySlipData = {
              'EMP_NAME': detail['EMP_NAME'] ?? 'N/A',
              'DESIGNATION': detail['DESIGNATION'] ?? 'N/A',
              'PAYMENT_METHOD': detail['PAYMENT_METHOD'] ?? 'N/A',
              'CUR_NAME': detail['CUR_NAME'] ?? 'N/A',
              'ACTUAL_BASIC_SAL':
                  (detail['ACTUAL_BASIC_SAL']?.toDouble() ?? 0.0),
              'PRL_GROUP_NAME': 'TECH MECH', // Set to constant
              'PRL_MONTH': selectedMonth, // From dropdown
              'DOC_DATE': DateTime.now(), // Today's date
              'TOTAL_MONTH_DAYS': detail['TOTAL_MONTH_DAYS']?.toInt() ?? 0,
              'TOTAL_WORKED_DAYS': detail['TOTAL_WORKED_DAYS']?.toInt() ?? 0,
              'TOTAL_ALLOWANCE': (detail['TOTAL_ALLOWANCE']?.toDouble() ?? 0.0),
              'TOTAL_DEDUCTION': (detail['TOTAL_DEDUCTION']?.toDouble() ?? 0.0),
              'NET_PAY': (detail['NET_PAY']?.toDouble() ?? 0.0),
              'GROSS_PAY': (detail['GROSS_PAY']?.toDouble() ?? 0.0),
            };
          });

          debugPrint('Parsed PaySlip Data: $paySlipData');
        } else {
          setState(() {
            errorMessage = 'No pay slip details found.';
          });
          debugPrint('No pay slip details found in response.');
        }
      } catch (e) {
        setState(() {
          errorMessage = 'Error fetching pay slip: $e';
        });
        debugPrint('Error fetching pay slip: $e');
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Helper method to build rounded text fields
  Widget _buildRoundedField({
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green),
          ),
          child: TextFormField(
            controller: controller,
            readOnly: readOnly,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter $label';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  // Helper method to build dropdown fields
  Widget _buildDropdownField({
    required String label,
    required List<String> items,
    required String value,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: const InputDecoration(
              border: InputBorder.none,
            ),
            items: items.map<DropdownMenuItem<String>>((String month) {
              return DropdownMenuItem<String>(
                value: month,
                child: Text(month),
              );
            }).toList(),
            onChanged: onChanged,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a $label';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  // Helper method to build section titles
  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
      ),
    );
  }

  // Method to build the Pay Slip card with fetched data
  Widget _buildPaySlipCard(Map<String, dynamic> data) {
    // Parse the document date
    DateTime docDate = data['DOC_DATE'] ?? DateTime.now();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TECH MECH', // Company Name
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Pay Slip',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              data['DESIGNATION'] ?? '',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Divider(
              color: Colors.green[300],
              thickness: 2,
            ),
            const SizedBox(height: 10),
            // Additional Details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDetailItem('PRL Group Name', data['PRL_GROUP_NAME']),
                _buildDetailItem('PRL Month', data['PRL_MONTH']),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDetailItem(
                    'Document Date', DateFormat.yMMMMd().format(docDate)),
              ],
            ),
            const SizedBox(height: 10),
            // Work Details
            _buildSectionTitle('Work Details'),
            const SizedBox(height: 10),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(3),
              },
              border: TableBorder.all(
                color: Colors.grey.shade300,
                style: BorderStyle.solid,
                width: 1,
              ),
              children: [
                _buildTableRow(
                    'Total Month Days', data['TOTAL_MONTH_DAYS'].toString()),
                _buildTableRow(
                    'Total Worked Days', data['TOTAL_WORKED_DAYS'].toString()),
              ],
            ),
            const SizedBox(height: 20),
            // Payment Details Section
            _buildSectionTitle('Payment Details'),
            const SizedBox(height: 10),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(3),
              },
              border: TableBorder.all(
                color: Colors.grey.shade300,
                style: BorderStyle.solid,
                width: 1,
              ),
              children: [
                _buildTableRow('Currency', data['CUR_NAME']),
                _buildTableRow('Payment Method', data['PAYMENT_METHOD']),
                _buildTableRow(
                    'Actual Basic Salary', 'PKR ${data['ACTUAL_BASIC_SAL']}'),
                _buildTableRow('Gross Pay', 'PKR ${data['GROSS_PAY']}'),
                _buildTableRow(
                    'Total Allowance', 'PKR ${data['TOTAL_ALLOWANCE']}'),
                _buildTableRow(
                    'Total Deduction', 'PKR ${data['TOTAL_DEDUCTION']}'),
                _buildTableRow('Net Pay', 'PKR ${data['NET_PAY']}'),
              ],
            ),
            const SizedBox(height: 30),
            // Export Button
            ElevatedButton.icon(
              onPressed: () {
                _downloadPDF(data);
              },
              icon: const Icon(Icons.download),
              label: const Text('Download PDF'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Method to handle PDF download
  Future<void> _downloadPDF(Map<String, dynamic> data) async {
    try {
      debugPrint('Generating PDF...');
      final pdf = pw.Document();

      // Parse dates
      DateTime docDate = data['DOC_DATE'] ?? DateTime.now();

      // Fetch the logo image from the URL
      final String logoUrl =
          'http://203.99.60.121:8090/SavedImages/EliteLogo.png';
      final http.Response logoResponse = await http.get(Uri.parse(logoUrl));

      if (logoResponse.statusCode != 200) {
        throw Exception('Failed to load logo image.');
      }

      final Uint8List logoBytes = logoResponse.bodyBytes;
      final pw.MemoryImage logoImage = pw.MemoryImage(logoBytes);

      // Define styles
      final pw.TextStyle headerStyle = pw.TextStyle(
        fontSize: 24,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.green800,
      );

      final pw.TextStyle subHeaderStyle = pw.TextStyle(
        fontSize: 16,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.green700,
      );

      final pw.TextStyle labelStyle = pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
      );

      final pw.TextStyle valueStyle = pw.TextStyle(
        fontSize: 14,
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) => [
            // Header with Logo and Company Name
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Image(logoImage, width: 150, height: 90),
                pw.Text('TECH MECH', // Company Name
                    style: headerStyle),
                pw.Text('Pay Slip', style: headerStyle),
              ],
            ),
            pw.SizedBox(height: 20),
            // Employee Information
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Employee Name:', style: labelStyle),
                    pw.Text(data['EMP_NAME'] ?? 'N/A', style: valueStyle),
                    pw.Text('Designation:', style: labelStyle),
                    pw.Text(data['DESIGNATION'] ?? 'N/A', style: valueStyle),
                    pw.Text('PRL Group Name:', style: labelStyle),
                    pw.Text(data['PRL_GROUP_NAME'] ?? 'N/A', style: valueStyle),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('PRL Month:', style: labelStyle),
                    pw.Text(data['PRL_MONTH'] ?? 'N/A', style: valueStyle),
                    pw.Text('Document Date:', style: labelStyle),
                    pw.Text(DateFormat.yMMMMd().format(docDate),
                        style: valueStyle),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            // Work Details
            pw.Text('Work Details', style: subHeaderStyle),
            pw.Table.fromTextArray(
              headers: ['Detail', 'Value'],
              data: [
                ['Total Month Days', data['TOTAL_MONTH_DAYS'].toString()],
                ['Total Worked Days', data['TOTAL_WORKED_DAYS'].toString()],
              ],
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerStyle: labelStyle,
              cellStyle: valueStyle,
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.green100),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.SizedBox(height: 20),
            // Payment Details
            pw.Text('Payment Details', style: subHeaderStyle),
            pw.Table.fromTextArray(
              headers: ['Description', 'Amount (PKR)'],
              data: [
                ['Currency', data['CUR_NAME'] ?? 'N/A'],
                ['Payment Method', data['PAYMENT_METHOD'] ?? 'N/A'],
                ['Actual Basic Salary', 'PKR ${data['ACTUAL_BASIC_SAL']}'],
                ['Gross Pay', 'PKR ${data['GROSS_PAY']}'],
                ['Total Allowance', 'PKR ${data['TOTAL_ALLOWANCE']}'],
                ['Total Deduction', 'PKR ${data['TOTAL_DEDUCTION']}'],
                ['Net Pay', 'PKR ${data['NET_PAY']}'],
              ],
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerStyle: labelStyle,
              cellStyle: valueStyle,
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.green100),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.SizedBox(height: 30),
            // Footer
            pw.Divider(color: PdfColors.green700, thickness: 1),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Thank you for your hard work!', style: valueStyle),
                pw.Text('Date: ${DateFormat.yMMMMd().format(DateTime.now())}',
                    style: valueStyle),
              ],
            ),
          ],
        ),
      );

      debugPrint('PDF generated successfully.');

      // Save or print the PDF
      await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save());

      debugPrint('PDF preview opened.');
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
        ),
      );
    }
  }

  // Helper method to build individual detail items
  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  // Helper method to build table rows with consistent styling
  TableRow _buildTableRow(String label, String value) {
    return TableRow(children: [
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          value,
          style: const TextStyle(fontSize: 14, color: Colors.black),
        ),
      ),
    ]);
  }
}
