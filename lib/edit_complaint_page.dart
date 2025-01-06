import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

final Logger logger = Logger(); // Logger for debugging

/// Model for holding attached images with their original names
class AttachedImage {
  final XFile file;
  final String originalName;

  AttachedImage({required this.file, required this.originalName});
}

/// Model for Resolver (Employee) fetched from the API
class Resolver {
  final String key; // Resolver Name
  final String value; // Resolver ID

  Resolver({required this.key, required this.value});

  factory Resolver.fromJson(Map<String, dynamic> json) {
    return Resolver(
      key: json['Key'],
      value: json['Value'],
    );
  }

  @override
  String toString() {
    return key;
  }
}

class EditComplaintPage extends StatefulWidget {
  /// Pass the existing complaint data from ComplaintHistoryPage
  final Map<String, dynamic> complaintData;

  const EditComplaintPage({super.key, required this.complaintData});

  @override
  _EditComplaintPageState createState() => _EditComplaintPageState();
}

class _EditComplaintPageState extends State<EditComplaintPage> {
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();

  // Fields for complaint data (example)
  final TextEditingController _complaintNameController =
      TextEditingController();
  final TextEditingController _mobileNumberController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _documentDateController = TextEditingController();

  // For employees (resolvers)
  List<Resolver> _resolvers = [];
  bool _isFetchingEmployees = false;
  String _resolverId = ''; // Will store the selected resolver's Value (ID)
  String _resolverDisplay = ''; // Will store the selected resolver's Key (Name)

  // For images
  final List<AttachedImage> _attachedImages = [];
  bool _isSubmitting = false;

  // For location fetching (if needed)
  bool _isLocationFetching = false;

  // For status (Open/Resolved)
  String _status =
      'Open'; // Convert to numeric for backend if needed (1->Open, 2->Resolved)

  @override
  void initState() {
    super.initState();
    _populateExistingData();
    _fetchEmployees();
    _fetchLocation(); // If you want to auto-fetch location on init
  }

  /// Populate fields with existing complaint data
  void _populateExistingData() {
    _complaintNameController.text =
        widget.complaintData['COMPLAINT_NAME']?.toString() ?? '';
    _mobileNumberController.text =
        widget.complaintData['MOBILE_NUMBER']?.toString() ?? '';
    _locationController.text =
        widget.complaintData['LOCATION']?.toString() ?? '';
    _descriptionController.text =
        widget.complaintData['DESCRIPTION']?.toString() ?? '';

    // Convert numeric status to text
    final existingStatus = widget.complaintData['STATUS']?.toString() ?? '1';
    _status = (existingStatus == '2') ? 'Resolved' : 'Open';

    // If your complaint already has a resolver
    final existingResolverId =
        widget.complaintData['RESOLVER_ID']?.toString() ?? '';
    if (existingResolverId.isNotEmpty) {
      _resolverId = existingResolverId;
      // Optionally fetch the name if included, e.g. "RESOLVER_NAME"
      _resolverDisplay =
          widget.complaintData['RESOLVER_NAME']?.toString() ?? '';
    }

    // Document date
    _documentDateController.text =
        widget.complaintData['DOC_DATE']?.toString() ??
            DateFormat('dd/MM/yyyy').format(DateTime.now());
  }

  /// Fetch employees (resolvers) from API
  Future<void> _fetchEmployees() async {
    setState(() => _isFetchingEmployees = true);

    try {
      final empId = await _storage.read(key: 'empId') ?? '';
      final accessToken = await _storage.read(key: 'accessToken') ?? '';
      if (empId.isEmpty || accessToken.isEmpty) {
        logger.w('empId or accessToken missing in secure storage.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('empId or accessToken missing. Please log in again.')),
        );
        return;
      }

      final url =
          'https://api.teckmech.com:8083/api/GENDropDown/GetEmployeesbyReportsTo?Id=$empId';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      // <-- added
      logger.i('Fetch Employees API Response: '
          'Status: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _resolvers = data.map((e) => Resolver.fromJson(e)).toList();
        });
      } else {
        logger.e('Failed to fetch employees. Code: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to fetch resolvers. Status Code: ${response.statusCode}')),
        );
      }
    } catch (e, s) {
      logger.e('Error fetching employees: $e');
      logger.e(s);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching resolvers: $e')),
      );
    } finally {
      setState(() => _isFetchingEmployees = false);
    }
  }

  /// Pick images from camera or gallery
  Future<void> _pickImages() async {
    try {
      final picker = ImagePicker();

      // Let user choose camera or gallery
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Attach Picture'),
            content: const Text('Choose the source of the picture.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(ImageSource.camera),
                child: const Text('Camera'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
                child: const Text('Gallery'),
              ),
            ],
          );
        },
      );

      if (source == null) return;

      List<XFile> selectedImages = [];
      if (source == ImageSource.gallery) {
        selectedImages = await picker.pickMultiImage();
      } else {
        final singleImage = await picker.pickImage(source: source);
        if (singleImage != null) selectedImages.add(singleImage);
      }

      for (var image in selectedImages) {
        final ext = path.extension(image.path).toLowerCase();
        if (!['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(ext)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unsupported file type: $ext')),
          );
          logger.w('Unsupported file type: $ext');
          continue;
        }
        final originalName = path.basename(image.path);
        _attachedImages
            .add(AttachedImage(file: image, originalName: originalName));
        logger.d('Added image: $originalName');
      }
      setState(() {});
    } catch (e) {
      logger.e('Failed to pick images: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick images: $e')),
      );
    }
  }

  /// Remove an attached image
  void _removeImage(AttachedImage image) {
    setState(() {
      _attachedImages.remove(image);
    });
    logger.d('Removed image: ${image.originalName}');
  }

  /// (Optional) Fetch location
  Future<void> _fetchLocation() async {
    setState(() => _isLocationFetching = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled.')));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Location permissions are permanently denied. Cannot request permissions.')));
        return;
      }
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')));
        return;
      }

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _locationController.text =
          'Lat: ${position.latitude}, Lon: ${position.longitude}';
      logger.d('Fetched location: ${_locationController.text}');
    } catch (e) {
      logger.e('Failed to fetch location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch location: $e')),
      );
    } finally {
      setState(() => _isLocationFetching = false);
    }
  }

  /// Validate and submit the form
  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _showSaveConfirmationDialog();
    }
  }

  /// Confirm the update
  void _showSaveConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Complaint'),
          content:
              const Text('Are you sure you want to update this complaint?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _updateComplaint();
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  /// Main update logic:
  /// 1) Send PUT to UpdateComplaint -> get GUID or relevant data
  /// 2) If success (200 or 201), proceed to upload images
  Future<void> _updateComplaint() async {
    setState(() => _isSubmitting = true);
    try {
      final accessToken = await _storage.read(key: 'accessToken') ?? '';
      if (accessToken.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access token missing. Login again.')),
        );
        return;
      }

      // Retrieve username from secure storage
      String? username = await _storage.read(key: 'username');
      if (username == null || username.isEmpty) {
        logger.e('_updateComplaint: Username not found.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Username not found. Please log in again.')),
        );
        return;
      }

      // Convert "Open"/"Resolved" to numeric if backend needs it
      final numericStatus = (_status.toLowerCase() == 'resolved') ? 2 : 1;

      // Combine original image names as REF_ATTACH_DOC_ID
      final refAttachDocId = _attachedImages.isNotEmpty
          ? _attachedImages.map((img) => img.originalName).join(',')
          : '';

      // Build request body
      final Map<String, dynamic> body = {
        "COMPLAINTKPI_ID": widget.complaintData['COMPLAINTKPI_ID'] ?? 0,
        "COMPLAINT_NAME": _complaintNameController.text,
        "MOBILE_NUMBER": _mobileNumberController.text,
        "LOCATION": _locationController.text,
        "DESCRIPTION": _descriptionController.text,
        "RESOLVER_ID": _resolverId.isEmpty ? 0 : int.parse(_resolverId),
        "STATUS": numericStatus,
        "REF_ATTACH_DOC_ID": refAttachDocId,
        // ... Hardcoded or additional fields:
        "DOC_DRAFT_NO": widget.complaintData['DOC_DRAFT_NO'] ?? 'CKPI\\03\\DEC',
        "DOC_NO": widget.complaintData['DOC_NO'] ?? '',
        "DOC_TYPE_ID": 356,
        "DOC_DATE": _documentDateController.text,
        "SERIAL_DRAFT_NO": 3,
        "SERIAL_NO": 0,
        "DOC_STATUS": 0,
        "DOC_STATUS_TEXT": "Draft",
        "APV_CYCLE": 0,
        "APV_STATUS": 0,
        "APV_STATUS_TEXT": "Pending",
        "CO_BRANCH_ID": 2,
        "CO_BRANCH_NAME": widget.complaintData['BRANCH_NAME'] ?? 'SampleBranch',
        "USER_DEPT_ID": 1,
        "USER_DEPT_NAME": widget.complaintData['DEPT_NAME'] ?? 'SampleDept',
        "LIC_ACC_ID": 1,
        "CO_ID": 1,
        "FROM_DATE": "2024-12-31T20:17:05.4102859",
        "TO_DATE": "2024-12-31T20:17:05.4102859",
        "COUNTRY_ID": 26,
        "PROVINCE_ID": 27,
        "DISTRICT_ID": 28,
        "TEHSIL_ID": 29,
        "UC_ID": 30,
        "BEAT_ID": 31,
        "CITY_ID": 32,
        "EMPLOYEE_ID": 33,
        "CREATED_BY": username, // Use username from secure storage
        "MODIFY_BY": username, // Use username from secure storage
        "CREATED_DATE": DateTime.now().toIso8601String(),
        "MODIFY_DATE": DateTime.now().toIso8601String(),
      };

      logger.d('UpdateComplaint request body: $body');

      const String updateUrl =
          'https://api.teckmech.com:8083/api/Complaint/UpdateComplaint';

      final response = await http.put(
        Uri.parse(updateUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      // <-- added
      logger.i('UpdateComplaint API Response: '
          'Status: ${response.statusCode}, Body: ${response.body}');

      // NOTE: Some APIs return 201 instead of 200 when "updated successfully."
      if (response.statusCode == 200 || response.statusCode == 201) {
        // If the body is JSON, parse it
        final responseData = jsonDecode(response.body);

        // If your API returns the guid in 'guid'
        final guid = responseData['guid'];
        logger.i('GUID from UpdateComplaint: $guid'); // <-- added

        // If guid is empty, you can still continue or handle as needed
        // For example, your API might return an actual filename in 'guid'.
        // We'll just treat it as a success signal.
        if (guid == null || guid.isEmpty) {
          logger.w('GUID was empty in update response.');
        }

        // Step 2: If images exist, upload them with the GUID
        // (only if the backend expects a GUID or filename)
        if (_attachedImages.isNotEmpty) {
          await _uploadImages(guid ?? '', accessToken);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Complaint updated successfully.')),
        );
        Navigator.of(context).pop(); // Return to previous screen
      } else {
        // If status is not 200 or 201, treat as error
        String errorMessage = 'Failed to update complaint.';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map && errorData.containsKey('message')) {
            errorMessage = errorData['message'];
          }
        } catch (_) {}
        throw Exception('$errorMessage (status: ${response.statusCode})');
      }
    } catch (e) {
      logger.e('Error updating complaint: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update complaint: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  /// Upload images after getting GUID from UpdateComplaint
  Future<void> _uploadImages(String guid, String accessToken) async {
    for (final attachedImage in _attachedImages) {
      try {
        final ext = path.extension(attachedImage.file.path).toLowerCase();
        final compressedBytes = await _compressImage(
          File(attachedImage.file.path),
          ext,
        );

        final baseName =
            path.basenameWithoutExtension(attachedImage.originalName);
        final newFileName = '${baseName}_$guid$ext';

        final uploadUrl =
            'https://api.teckmech.com:8083/api/Complaint/updateImage';

        final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
        request.headers['Authorization'] = 'Bearer $accessToken';

        // If your backend needs a 'guid', we pass it.
        // If it needs something else, change the field name.
        request.fields['guid'] = guid;
        logger.d('Sending guid in request: $guid'); // <-- added

        final mimeType = _getMimeType(ext);
        final multipartFile = http.MultipartFile.fromBytes(
          'file', // Key recognized by the server
          compressedBytes,
          filename: newFileName,
          contentType: mimeType,
        );
        request.files.add(multipartFile);

        logger
            .d('Uploading image ${attachedImage.originalName} -> $newFileName');

        // Send request
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        logger.d('updateImage Response: '
            'Status: ${response.statusCode}, Body: ${response.body}');

        if (response.statusCode == 200) {
          final respJson = jsonDecode(response.body);
          if (respJson['Status'] != 'OK') {
            throw Exception(
                'Image upload failed for ${attachedImage.originalName}.');
          }
          logger.i(
              'Image ${attachedImage.originalName} uploaded successfully as $newFileName.');
        } else {
          throw Exception(
              'Image upload failed. Status code: ${response.statusCode}');
        }
      } catch (e) {
        logger.e('Error uploading image ${attachedImage.originalName}: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to upload ${attachedImage.originalName}: $e')),
        );
      }
    }
  }

  /// Compress the image before upload (optional)
  Future<List<int>> _compressImage(File file, String ext) async {
    try {
      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        quality: 80,
        format: _getCompressFormat(ext),
      );
      if (result == null) throw Exception('Image compression returned null.');
      return result;
    } catch (e) {
      logger.e('Image compression error: $e');
      return file.readAsBytesSync();
    }
  }

  /// Determine compression format
  CompressFormat _getCompressFormat(String ext) {
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return CompressFormat.jpeg;
      case '.png':
        return CompressFormat.png;
      case '.webp':
        return CompressFormat.webp;
      default:
        return CompressFormat.jpeg;
    }
  }

  /// Determine MIME type
  MediaType _getMimeType(String ext) {
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return MediaType('image', 'jpeg');
      case '.png':
        return MediaType('image', 'png');
      case '.gif':
        return MediaType('image', 'gif');
      case '.bmp':
        return MediaType('image', 'bmp');
      case '.webp':
        return MediaType('image', 'webp');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  /// This method displays a dialog to select a resolver from the `_resolvers` list.
  void _selectResolver() async {
    final selectedResolver = await showDialog<Resolver>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Resolver'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Optional: Add a search bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search Resolver',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  onChanged: (value) {
                    // Implement search/filter functionality if needed
                  },
                ),
                SizedBox(height: 10),
                // List of resolvers
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _resolvers.length,
                    itemBuilder: (context, index) {
                      Resolver resolver = _resolvers[index];
                      return ListTile(
                        title: Text(resolver.key), // Display resolver name
                        onTap: () => Navigator.pop(context, resolver),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
    if (selectedResolver != null) {
      setState(() {
        _resolverId = selectedResolver.value;
        _resolverDisplay = selectedResolver.key;
      });
      logger.d('Selected resolver: $_resolverDisplay with ID: $_resolverId');
    }
  }

  /// Build the UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Complaint'),
        backgroundColor: const Color.fromARGB(255, 216, 155, 41),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Complaint Name
                  TextFormField(
                    controller: _complaintNameController,
                    decoration: const InputDecoration(
                      labelText: 'Complaint Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Please enter complaint name'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Mobile Number
                  TextFormField(
                    controller: _mobileNumberController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Mobile Number',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter mobile number';
                      } else if (!RegExp(r'^\d{11}$').hasMatch(value)) {
                        return 'Mobile number must be exactly 11 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Location
                  _isLocationFetching
                      ? const CircularProgressIndicator()
                      : TextFormField(
                          controller: _locationController,
                          decoration: const InputDecoration(
                            labelText: 'Location',
                            border: OutlineInputBorder(),
                          ),
                        ),
                  const SizedBox(height: 16),

                  // Resolver (Employees)
                  _isFetchingEmployees
                      ? const CircularProgressIndicator()
                      : GestureDetector(
                          onTap: () => _selectResolver(),
                          child: AbsorbPointer(
                            child: TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Resolver',
                                border: const OutlineInputBorder(),
                                suffixIcon: const Icon(Icons.arrow_drop_down),
                              ),
                              controller:
                                  TextEditingController(text: _resolverDisplay),
                              validator: (value) {
                                if (_resolverId.isEmpty) {
                                  return 'Please select a resolver';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                  const SizedBox(height: 16),

                  // Status (Open/Resolved)
                  DropdownButtonFormField<String>(
                    value: _status,
                    items: const [
                      DropdownMenuItem(
                        value: 'Open',
                        child: Text('Open'),
                      ),
                      DropdownMenuItem(
                        value: 'Resolved',
                        child: Text('Resolved'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (newVal) => setState(() => _status = newVal!),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Please enter description'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Attach images
                  ElevatedButton.icon(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Attach Picture'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 216, 155, 41),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Display attached images
                  _attachedImages.isNotEmpty
                      ? Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _attachedImages.map((image) {
                            return Stack(
                              alignment: Alignment.topRight,
                              children: [
                                Image.file(
                                  File(image.file.path),
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                                GestureDetector(
                                  onTap: () => _removeImage(image),
                                  child: const CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Colors.red,
                                    child: Icon(Icons.close,
                                        size: 16, color: Colors.white),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        )
                      : const Text(
                          'No pictures attached.',
                          style: TextStyle(color: Colors.grey),
                        ),

                  const SizedBox(height: 30),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 216, 155, 41),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      child: const Text('Update'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading overlay if submitting
          if (_isSubmitting)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Updating Complaint...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void main() => runApp(MaterialApp(
      home: EditComplaintPage(
        complaintData: {
          // Example complaint data; replace with actual data as needed
          'COMPLAINT_NAME': 'Sample Complaint',
          'MOBILE_NUMBER': '01234567890',
          'LOCATION': 'Lat: 12.3456, Lon: 65.4321',
          'DESCRIPTION': 'This is a sample complaint description.',
          'STATUS': '1', // '1' for Open, '2' for Resolved
          'RESOLVER_ID': '123', // Example resolver ID
          'RESOLVER_NAME': 'John Doe',
          'DOC_DATE': '31/12/2024',
          'DOC_DRAFT_NO': 'CKPI\\03\\DEC',
          'DOC_NO': '',
          'BRANCH_NAME': 'Main Branch',
          'DEPT_NAME': 'Customer Service',
          'COMPLAINTKPI_ID': 0,
        },
      ),
      theme: ThemeData(
        primaryColor: Color.fromARGB(255, 216, 155, 41),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
    ));
