import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Secure storage
import 'api_service.dart'; // Your ApiService

class CompanySelectionScreen extends StatefulWidget {
  const CompanySelectionScreen({super.key});

  @override
  _CompanySelectionScreenState createState() => _CompanySelectionScreenState();
}

class _CompanySelectionScreenState extends State<CompanySelectionScreen> {
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  String? _selectedCompany;
  bool _isDropdownEnabled = false;

  final List<String> companies = ['Tech Mech', 'FiNASAL', 'MABL']; // Added MABL

  @override
  void initState() {
    super.initState();
    _checkIfCompanySelected(); // Check if a company is already selected
  }

  // Function to check if the company is already selected and stored in secure storage
  Future<void> _checkIfCompanySelected() async {
    String? baseUrl =
        await _storage.read(key: 'base_url'); // Read base URL from storage
    if (baseUrl != null && baseUrl.isNotEmpty) {
      // If base URL is already set, navigate directly to the login page
      Navigator.pushReplacementNamed(context, '/');
    } else {
      // If no base URL is stored, let user select a company
      setState(() {
        _selectedCompany = 'Tech Mech'; // Default to 'FiNASAL'
      });
    }
  }

  // Function to set the base URL after selecting the company
  void _setBaseUrl() async {
    String baseUrl;
    if (_selectedCompany == 'Tech Mech') {
      baseUrl = 'https://api.teckmech.com:8083/';
    } else if (_selectedCompany == 'FiNASAL') {
      baseUrl = 'http://203.99.60.121:8090/';
    } else {
      baseUrl = 'http://203.99.60.121:8092/'; // Base URL for MABL
    }

    await ApiService.setBaseUrl(baseUrl); // Set the base URL in ApiService
    await _storage.write(
        key: 'base_url', value: baseUrl); // Store it in secure storage

    // Navigate to login page after selection
    Navigator.pushReplacementNamed(context, '/');
  }

  // Enable dropdown on double tap
  void _enableDropdown() {
    setState(() {
      _isDropdownEnabled = true; // Enable the dropdown
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade400, Colors.purple.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Text(
            'License Validation',
            style: TextStyle(
              color: const Color.fromARGB(255, 247, 238, 242),
              fontSize: 16, // Smaller font size
              fontWeight: FontWeight.w800, // Less bold font
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade400, Colors.purple.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Heading Text aligned towards the left
                Align(
                  alignment: Alignment.centerLeft, // Align to the left
                  child: GestureDetector(
                    onDoubleTap:
                        _enableDropdown, // Enable dropdown on double tap
                    child: Text(
                      'License for',
                      style: TextStyle(
                        fontSize: 20, // Smaller font size
                        fontWeight: FontWeight.bold,
                        color:
                            Colors.white.withOpacity(0.8), // Soft opaque color
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Dropdown container with soft rounded corners
                AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  padding: EdgeInsets.symmetric(
                      vertical: 12, horizontal: 18), // Reduced padding
                  child: DropdownButtonFormField<String>(
                    value: _selectedCompany,
                    onChanged: _isDropdownEnabled
                        ? (String? newValue) {
                            setState(() {
                              _selectedCompany = newValue!;
                            });
                          }
                        : null, // Disable dropdown if not enabled
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      icon: Icon(Icons.business, color: Colors.blue.shade600),
                    ),
                    style: TextStyle(
                      fontSize: 16, // Smaller font size
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade600,
                    ),
                    dropdownColor: Colors.blue.shade100, // Dropdown background
                    items: companies.map((company) {
                      return DropdownMenuItem<String>(
                        value: company,
                        child: Text(
                          company,
                          style: TextStyle(color: Colors.black),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 30),

                // Continue Button
                ElevatedButton(
                  onPressed: () {
                    if (_selectedCompany != null) {
                      _setBaseUrl(); // Set base URL and navigate to login
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: const Color.fromARGB(255, 223, 217, 217),
                    backgroundColor: const Color.fromARGB(255, 32, 148, 113),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: EdgeInsets.symmetric(
                        horizontal: 40, vertical: 12), // Smaller padding
                    textStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold), // Smaller text size
                    elevation: 5,
                  ),
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
