import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logger/logger.dart'; // Import the logger package
import 'package:path/path.dart'
    as path; // Import the path package for handling file paths
import 'package:http_parser/http_parser.dart'; // Import MediaType from http_parser
import 'package:flutter_image_compress/flutter_image_compress.dart'; // Optional: For image compression

final Logger logger = Logger(); // Initialize the logger

// Model to hold attached images with their original names
class AttachedImage {
  final XFile file;
  final String originalName;

  AttachedImage({required this.file, required this.originalName});
}

class Resolver {
  final String key;
  final String value;

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

class ComplaintPage extends StatefulWidget {
  const ComplaintPage({super.key});

  @override
  _ComplaintPageState createState() => _ComplaintPageState();
}

class _ComplaintPageState extends State<ComplaintPage> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  // Document Details Controllers (Auto-Filled)
  TextEditingController draftNumberController = TextEditingController();
  TextEditingController documentNumberController = TextEditingController();
  TextEditingController documentStatusController = TextEditingController();
  TextEditingController approvalStatusController = TextEditingController();
  TextEditingController branchController = TextEditingController();
  TextEditingController departmentController = TextEditingController();
  TextEditingController documentDateController = TextEditingController();

  // Complaint Details Controllers (User Input)
  TextEditingController complaintNameController = TextEditingController();
  TextEditingController mobileNumberController = TextEditingController();
  TextEditingController locationController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();

  String resolver = '';
  String resolverDisplay = '';
  String status = 'Open';
  bool _isLoading = false;
  bool _isLocationFetching = false;
  bool _showDocumentDetails = false;
  bool _isFetchingResolvers = false;
  bool _isSubmitting = false;

  // Secure storage instance
  final storage = FlutterSecureStorage();

  // Resolver List
  List<Resolver> _resolvers = [];

  // Variable to store attached images with original names
  final List<AttachedImage> _attachedImages = [];

  // Optional: Mapping of original to renamed image names
  final Map<String, String> _imageNameMapping = {};

  @override
  void initState() {
    super.initState();
    _fetchDocumentDetails();
    _fetchLocation();
    _loadDraftData();
    _fetchResolvers();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(seconds: 1),
        curve: Curves.easeInOut,
      );
    });

    // **Temporary: Store a username for testing purposes**
    // **Remove or secure this in production**
    storage.write(key: 'username', value: 'john_doe');
  }

  @override
  void dispose() {
    draftNumberController.dispose();
    documentNumberController.dispose();
    documentStatusController.dispose();
    approvalStatusController.dispose();
    branchController.dispose();
    departmentController.dispose();
    documentDateController.dispose();
    complaintNameController.dispose();
    mobileNumberController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchDocumentDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Simulate network delay
      await Future.delayed(Duration(seconds: 2));

      // In a real scenario, replace the following with actual API calls
      setState(() {
        draftNumberController.text = 'DRAFT123456';
        documentNumberController.text = 'DOC654321';
        documentStatusController.text = 'In Progress';
        approvalStatusController.text = 'Pending Approval';
        branchController.text = 'Main Branch';
        departmentController.text = 'Customer Service';
        documentDateController.text =
            DateFormat('dd/MM/yyyy').format(DateTime.now());
      });

      logger.i('Fetched document details successfully.');
    } catch (e) {
      logger.e('Failed to fetch document details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch document details: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _isLocationFetching = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        logger.w('Location services are disabled.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location services are disabled.')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          logger.w('Location permissions are denied');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Location permissions are denied')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        logger.w(
            'Location permissions are permanently denied, we cannot request permissions.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Location permissions are permanently denied, we cannot request permissions.')),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        locationController.text =
            'Lat: ${position.latitude}, Lon: ${position.longitude}';
      });

      logger.d('Fetched location: ${locationController.text}');
    } catch (e) {
      logger.e('Failed to fetch location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch location: $e')),
      );
    } finally {
      setState(() {
        _isLocationFetching = false;
      });
    }
  }

  // Load draft data from secure storage
  Future<void> _loadDraftData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      complaintNameController.text =
          await storage.read(key: 'complaintName') ?? '';
      mobileNumberController.text =
          await storage.read(key: 'mobileNumber') ?? '';
      locationController.text = await storage.read(key: 'location') ?? '';
      descriptionController.text = await storage.read(key: 'description') ?? '';
      resolver = await storage.read(key: 'resolver') ?? '';
      resolverDisplay = await storage.read(key: 'resolverDisplay') ?? '';
      status = await storage.read(key: 'status') ?? 'Open';

      // Load attached images if any
      String? imagesJson = await storage.read(key: 'attachedImages');
      if (imagesJson != null) {
        List<dynamic> imagesData = jsonDecode(imagesJson);
        setState(() {
          _attachedImages.addAll(imagesData.map((imgData) {
            return AttachedImage(
              file: XFile(imgData['path']),
              originalName: imgData['originalName'],
            );
          }).toList());
        });
        logger.d('Loaded attached images from draft.');
      }

      logger.i('Loaded draft data successfully.');
    } catch (e) {
      logger.e('Failed to load draft data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load draft data: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Save draft data to secure storage
  Future<void> _saveDraftData() async {
    try {
      await storage.write(
          key: 'complaintName', value: complaintNameController.text);
      await storage.write(
          key: 'mobileNumber', value: mobileNumberController.text);
      await storage.write(key: 'location', value: locationController.text);
      await storage.write(
          key: 'description', value: descriptionController.text);
      await storage.write(key: 'resolver', value: resolver);
      await storage.write(key: 'resolverDisplay', value: resolverDisplay);
      await storage.write(key: 'status', value: status);

      // Save image paths and original names
      List<Map<String, String>> imagesData = _attachedImages.map((img) {
        return {
          'path': img.file.path,
          'originalName': img.originalName,
        };
      }).toList();
      await storage.write(key: 'attachedImages', value: jsonEncode(imagesData));

      logger.i('Draft data saved successfully.');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Complaint saved as draft.')),
      );
    } catch (e) {
      logger.e('Failed to save draft: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save draft: $e')),
      );
    }
  }

  // Clear draft data after saving permanently
  Future<void> _clearDraftData() async {
    try {
      await storage.delete(key: 'complaintName');
      await storage.delete(key: 'mobileNumber');
      await storage.delete(key: 'location');
      await storage.delete(key: 'description');
      await storage.delete(key: 'resolver');
      await storage.delete(key: 'resolverDisplay');
      await storage.delete(key: 'status');
      await storage.delete(key: 'attachedImages');

      setState(() {
        _attachedImages.clear();
        _imageNameMapping.clear();
        complaintNameController.clear();
        mobileNumberController.clear();
        locationController.clear();
        descriptionController.clear();
        resolver = '';
        resolverDisplay = '';
        status = 'Open';
      });

      logger.i('Draft data cleared after permanent submission.');
    } catch (e) {
      logger.e('Failed to clear draft data: $e');
      // Handle errors if any
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _showSaveOptions();
    }
  }

  void _showSaveOptions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Save Options'),
          content: Text('Choose how you would like to save this complaint.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _saveDraftData(); // Save the draft data
              },
              child: Text('Save as Draft'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _savePermanently(); // Save permanently and clear the draft data
              },
              child: Text('Save Permanently'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _savePermanently() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      // Step 1: Submit Complaint Data to CreateComplaint API
      String? accessToken = await storage.read(key: 'accessToken');
      if (accessToken == null || accessToken.isEmpty) {
        logger.e('_savePermanently: Access token not found.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Access token missing. Please log in again.')),
        );
        return;
      }

      // Retrieve username from secure storage
      String? username = await storage.read(key: 'username');
      if (username == null || username.isEmpty) {
        logger.e('_savePermanently: Username not found.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Username not found. Please log in again.')),
        );
        return;
      }

      // Prepare REF_ATTACH_DOC_ID by joining original image names
      String refAttachDocId = _attachedImages.isNotEmpty
          ? _attachedImages.map((img) => img.originalName).join(',')
          : '';

      // Construct the API payload
      Map<String, dynamic> complaintData = {
        "LIC_ACC_ID": "1",
        "CO_ID": "1",
        "COMPLAINTKPI_ID": "",
        "DOC_DRAFT_NO": "CKPI\\03\\DEC",
        "DOC_NO": null,
        "DOC_TYPE_ID": 356,
        "DOC_DATE": documentDateController.text,
        "SERIAL_DRAFT_NO": 3,
        "SERIAL_NO": 0,
        "DOC_STATUS": 0,
        "APV_CYCLE": 0,
        "APV_STATUS": 0,
        "CO_BRANCH_ID": "2",
        "COMPLAINT_NAME": complaintNameController.text,
        "MOBILE_NUMBER": mobileNumberController.text,
        "LOCATION": locationController.text,
        "RESOLVER_ID": resolver,
        "STATUS": "1",
        "DESCRIPTION": descriptionController.text,
        "DOC_STATUS_TEXT": "Draft",
        "CO_BRANCH_NAME": branchController.text,
        "USER_DEPT_NAME": departmentController.text,
        "REF_ATTACH_DOC_ID": refAttachDocId, // Set the original image names
        "USER_DEPT_ID": 1,
        "CREATED_BY": username, // Use username from secure storage
        "CREATED_DATE": DateTime.now().toIso8601String(),
        "MODIFY_BY": username, // Use username from secure storage
        "MODIFY_DATE": DateTime.now().toIso8601String(),
      };

      // API URL for CreateComplaint
      final String createComplaintUrl =
          'https://api.teckmech.com:8083/api/Complaint/CreateComplaint';

      logger.d(
          'Submitting complaint data to CreateComplaint API: ${jsonEncode(complaintData)}');

      // Send the POST request
      var createResponse = await http.post(
        Uri.parse(createComplaintUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(complaintData),
      );

      logger.d(
          'CreateComplaint API Response: ${createResponse.statusCode} - ${createResponse.body}');

      if (createResponse.statusCode == 200 ||
          createResponse.statusCode == 201) {
        var createResponseData = jsonDecode(createResponse.body);
        String guid = createResponseData['guid'] ?? '';

        if (guid.isEmpty) {
          throw Exception('GUID not returned from CreateComplaint API.');
        }

        logger.i('Received GUID: $guid');

        // Step 2: Upload Images with GUID to UpdateImage API
        if (_attachedImages.isNotEmpty) {
          final String updateImageUrl =
              'https://api.teckmech.com:8083/api/Complaint/updateImage';

          List<Future<void>> uploadFutures =
              _attachedImages.map((AttachedImage attachedImage) async {
            // Extract the file extension
            String fileExtension =
                path.extension(attachedImage.file.path).toLowerCase();

            // Debug logs to verify the extension
            logger.d('Image Path: ${attachedImage.file.path}');
            logger.d('Extracted File Extension: $fileExtension');

            // Ensure the file extension is valid
            if (!['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp']
                .contains(fileExtension)) {
              throw Exception(
                  'Unsupported file extension: $fileExtension for image ${attachedImage.originalName}');
            }

            // Rename the file by appending the GUID to the original name (before extension)
            String baseName =
                path.basenameWithoutExtension(attachedImage.originalName);
            String newFileName = '${baseName}_$guid$fileExtension';

            // Read the image bytes
            File imageFile = File(attachedImage.file.path);

            // Optional: Compress the image to reduce size
            List<int> bytes = await _compressImage(imageFile, fileExtension);

            // Determine the MIME type
            MediaType? mimeType = _getMimeType(fileExtension);
            if (mimeType == null) {
              mimeType =
                  MediaType('application', 'octet-stream'); // Default MIME type
              logger.w(
                  'Unknown file extension: $fileExtension. Defaulting MIME type to application/octet-stream');
            }

            logger.d('Determined MIME Type: $mimeType');

            // Create MultipartFile using fromBytes
            var multipartFile = http.MultipartFile.fromBytes(
              'file', // Must match the server-side key
              bytes,
              filename: newFileName, // Using original name with GUID
              contentType: mimeType,
            );

            var request =
                http.MultipartRequest('POST', Uri.parse(updateImageUrl));
            request.headers['Authorization'] = 'Bearer $accessToken';

            // Add the MultipartFile
            request.files.add(multipartFile);

            // Add the GUID as a form field
            request.fields['guid'] = guid;

            // Log the fields and files being sent
            logger.d('UpdateImage Request Fields: ${request.fields}');
            logger.d(
                'UpdateImage Request Files: ${request.files.map((f) => f.filename).toList()}');

            logger.d(
                'Uploading image to UpdateImage API: $newFileName with GUID: $guid');

            // Send the request
            var uploadResponse = await request.send();
            var uploadResult = await http.Response.fromStream(uploadResponse);

            logger.d(
                'UpdateImage API Response for ${attachedImage.originalName}: ${uploadResponse.statusCode} - ${uploadResult.body}');

            if (uploadResponse.statusCode == 200 ||
                uploadResponse.statusCode == 201) {
              var uploadResponseData = jsonDecode(uploadResult.body);
              if (uploadResponseData['Status'] != 'OK') {
                throw Exception(
                    'Image upload failed for ${attachedImage.originalName}.');
              } else {
                logger.i(
                    'Image ${attachedImage.originalName} uploaded successfully as $newFileName.');
              }
            } else {
              throw Exception(
                  'Image upload failed for ${attachedImage.originalName}. Status Code: ${uploadResponse.statusCode}');
            }
          }).toList();

          // Wait for all uploads to complete
          await Future.wait(uploadFutures);
        }

        // If everything is successful
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Complaint saved permanently.')),
        );

        logger.i('Complaint with GUID $guid saved permanently.');

        // Clear the draft data after successful submission
        _clearDraftData();
      } else {
        logger.e(
            '_savePermanently: Failed to submit complaint. Status code: ${createResponse.statusCode}, Body: ${createResponse.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to save complaint: ${createResponse.body}')),
        );
      }
    } catch (e) {
      logger.e('_savePermanently: Exception during complaint submission: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  // Optional: Compress the image to reduce size
  Future<List<int>> _compressImage(File file, String fileExtension) async {
    try {
      var result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        quality: 80, // Adjust quality as needed
        format: _getCompressFormat(fileExtension),
      );
      if (result == null) throw Exception('Image compression failed.');
      return result;
    } catch (e) {
      logger.e('Image compression failed: $e');
      // If compression fails, return original bytes
      return await file.readAsBytes();
    }
  }

  // Determine the compression format based on file extension
  CompressFormat _getCompressFormat(String fileExtension) {
    switch (fileExtension) {
      case '.jpg':
      case '.jpeg':
        return CompressFormat.jpeg;
      case '.png':
        return CompressFormat.png;
      case '.webp':
        return CompressFormat.webp;
      default:
        return CompressFormat.jpeg; // Default to JPEG
    }
  }

  // Method to determine MIME type based on file extension
  MediaType? _getMimeType(String fileExtension) {
    switch (fileExtension) {
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
        logger.w(
            'Unknown file extension: $fileExtension. Defaulting to application/octet-stream');
        return MediaType('application', 'octet-stream'); // Default MIME type
    }
  }

  // Method to pick images
  Future<void> _pickImages() async {
    try {
      final ImagePicker picker = ImagePicker();

      // Ask the user if they want to use the camera or gallery
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Attach Picture'),
            content: Text('Choose the source of the picture.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(ImageSource.camera),
                child: Text('Camera'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
                child: Text('Gallery'),
              ),
            ],
          );
        },
      );

      if (source == null) {
        // User canceled the dialog
        return;
      }

      List<XFile> selectedImages = [];

      if (source == ImageSource.gallery) {
        selectedImages = await picker.pickMultiImage();
      } else {
        final XFile? image = await picker.pickImage(source: ImageSource.camera);
        if (image != null) {
          selectedImages.add(image);
        }
      }

      if (selectedImages.isNotEmpty) {
        // Validate image extensions and store original names
        for (var image in selectedImages) {
          String extension = path.extension(image.path).toLowerCase();
          if (!['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp']
              .contains(extension)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Unsupported file type: $extension')),
            );
            logger.w('Unsupported file type selected: $extension');
            continue; // Skip unsupported files
          }
          String originalName = path.basename(image.path);
          _attachedImages
              .add(AttachedImage(file: image, originalName: originalName));
          logger.d(
              'Added image: ${image.path} with original name: $originalName');
        }
        setState(() {}); // Refresh UI after adding images
      }
    } catch (e) {
      logger.e('Failed to pick images: $e');
      // Handle any errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick images: $e')),
      );
    }
  }

  Future<void> _fetchResolvers() async {
    setState(() {
      _isFetchingResolvers = true;
    });

    final String baseApiUrl =
        'https://api.teckmech.com:8083/api/GENDropDown/GetEmployeesbyReportsTo';

    try {
      // Retrieve empId from secure storage
      String? empId = await storage.read(key: 'empId');

      if (empId == null || empId.isEmpty) {
        logger.w('Employee ID not found.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Employee ID not found. Please log in again.')),
        );
        return; // Exit the method if empId is not found
      }

      // Retrieve access token from secure storage
      String? accessToken = await storage.read(key: 'accessToken');

      if (accessToken == null || accessToken.isEmpty) {
        logger.w('Access token not found.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Access token not found. Please log in again.')),
        );
        return; // Exit the method if token is not found
      }

      // Construct the API URL with empId
      String apiUrl = '$baseApiUrl?Id=$empId';

      logger.d('Fetching resolvers from: $apiUrl');

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $accessToken', // Added Authorization header
          'Content-Type': 'application/json', // Ensure content type is JSON
        },
      ).timeout(Duration(seconds: 15));

      logger.d(
          'GetEmployeesbyReportsTo API Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        setState(() {
          _resolvers = data.map((item) => Resolver.fromJson(item)).toList();
        });

        logger.i('Fetched ${_resolvers.length} resolvers.');
      } else if (response.statusCode == 401) {
        // Unauthorized - Token might be expired or invalid
        logger.w('Unauthorized access while fetching resolvers.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unauthorized access. Please log in again.')),
        );
        // Optionally, navigate back to the login page
        // Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LoginPage()));
      } else {
        logger
            .e('Failed to load resolvers. Status Code: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to load resolvers. Status Code: ${response.statusCode}')),
        );
      }
    } catch (e) {
      logger.e('An error occurred while fetching resolvers: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('An error occurred while fetching resolvers: $e')),
      );
    } finally {
      setState(() {
        _isFetchingResolvers = false;
      });
    }
  }

  // Method to open custom resolver selection dialog
  Future<void> _selectResolver() async {
    TextEditingController searchController = TextEditingController();
    List<Resolver> tempFilteredResolvers = List.from(_resolvers);

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          // Need to use StatefulBuilder to manage the state of the dialog
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Select Resolver'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search Resolver',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          tempFilteredResolvers = _resolvers
                              .where((resolver) => resolver.key
                                  .toLowerCase()
                                  .contains(value.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                    SizedBox(height: 10),
                    Expanded(
                      child: tempFilteredResolvers.isNotEmpty
                          ? ListView.builder(
                              shrinkWrap: true,
                              itemCount: tempFilteredResolvers.length,
                              itemBuilder: (context, index) {
                                Resolver currentResolver =
                                    tempFilteredResolvers[index];
                                return ListTile(
                                  title: Text(currentResolver.key),
                                  onTap: () {
                                    setState(() {
                                      resolver = currentResolver.value;
                                      resolverDisplay = currentResolver.key;
                                    });
                                    // Save the selected resolver
                                    Navigator.of(context).pop();
                                    logger.d(
                                        'Selected resolver: $resolverDisplay with ID: $resolver');
                                  },
                                );
                              },
                            )
                          : Center(child: Text('No resolvers found')),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
                  },
                  child: Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    // Update the state after selection
    setState(() {});
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildReadOnlyField({
    required TextEditingController controller,
    required String labelText,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        filled: true,
        fillColor: Colors.grey[200],
        contentPadding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    TextInputType? keyboardType,
    int? maxLines,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType ?? TextInputType.text,
      maxLines: maxLines ?? 1,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
      ),
      validator: validator,
    );
  }

  Widget _buildResolverField() {
    return GestureDetector(
      onTap: _isFetchingResolvers ? null : _selectResolver,
      child: AbsorbPointer(
        child: TextFormField(
          controller: TextEditingController(text: resolverDisplay),
          decoration: InputDecoration(
            labelText: 'Resolver',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            suffixIcon: Icon(Icons.arrow_drop_down),
            contentPadding:
                EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
          ),
          validator: (value) {
            if (resolver.isEmpty) {
              return 'Please select a resolver';
            }
            return null;
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Complaint Form'),
        backgroundColor: const Color.fromARGB(255, 216, 155, 41),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Stack(
              children: [
                SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Document Details with Toggle Visibility
                      _buildSectionTitle('Document Details'),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Show Document Details',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          IconButton(
                            icon: Icon(
                              _showDocumentDetails
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey[700],
                            ),
                            onPressed: () {
                              setState(() {
                                _showDocumentDetails = !_showDocumentDetails;
                              });
                            },
                          ),
                        ],
                      ),
                      if (_showDocumentDetails)
                        _isLoading
                            ? Center(child: CircularProgressIndicator())
                            : Column(
                                children: [
                                  _buildReadOnlyField(
                                    controller: draftNumberController,
                                    labelText: 'Draft Number',
                                  ),
                                  SizedBox(height: 16),
                                  _buildReadOnlyField(
                                    controller: documentNumberController,
                                    labelText: 'Document Number',
                                  ),
                                  SizedBox(height: 16),
                                  _buildReadOnlyField(
                                    controller: documentStatusController,
                                    labelText: 'Document Status',
                                  ),
                                  SizedBox(height: 16),
                                  _buildReadOnlyField(
                                    controller: approvalStatusController,
                                    labelText: 'Approval Status',
                                  ),
                                  SizedBox(height: 16),
                                  _buildReadOnlyField(
                                    controller: branchController,
                                    labelText: 'Branch',
                                  ),
                                  SizedBox(height: 16),
                                  _buildReadOnlyField(
                                    controller: departmentController,
                                    labelText: 'Department',
                                  ),
                                  SizedBox(height: 16),
                                  _buildReadOnlyField(
                                    controller: documentDateController,
                                    labelText: 'Document Date',
                                  ),
                                ],
                              ),
                      SizedBox(height: 24),
                      // Complaint Details Section
                      _buildSectionTitle('Complaint Details'),
                      SizedBox(height: 10),
                      _buildTextField(
                        controller: complaintNameController,
                        labelText: 'Complaint Name',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter complaint name';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: mobileNumberController,
                        labelText: 'Mobile Number',
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter mobile number';
                          } else if (!RegExp(r'^\d{11}$').hasMatch(value)) {
                            return 'Mobile number must be exactly 11 digits';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      _isLocationFetching
                          ? Center(child: CircularProgressIndicator())
                          : _buildTextField(
                              controller: locationController,
                              labelText: 'Location',
                              validator: null,
                            ),
                      SizedBox(height: 16),
                      _isFetchingResolvers
                          ? Center(child: CircularProgressIndicator())
                          : _buildResolverField(),
                      SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: status,
                        items: ['Open', 'Closed', 'Pending']
                            .map((String value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                ))
                            .toList(),
                        decoration: InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 15.0, horizontal: 10.0),
                        ),
                        onChanged: (newValue) {
                          setState(() {
                            status = newValue!;
                          });
                        },
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: descriptionController,
                        labelText: 'Description',
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter description';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      // Attach Picture Button
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton.icon(
                          onPressed: _pickImages,
                          icon: Icon(Icons.camera_alt),
                          label: Text('Attach Picture'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.fromARGB(255, 216, 155, 41),
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      _attachedImages.isNotEmpty
                          ? Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children:
                                  _attachedImages.map((AttachedImage image) {
                                return SizedBox(
                                  width: 100,
                                  child: Stack(
                                    alignment: Alignment.topRight,
                                    children: [
                                      Image.file(
                                        File(image.file.path),
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _attachedImages.remove(image);
                                          });
                                          logger.d(
                                              'Removed image: ${image.originalName}');
                                        },
                                        child: CircleAvatar(
                                          radius: 12,
                                          backgroundColor: Colors.red,
                                          child: Icon(Icons.close,
                                              size: 16, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            )
                          : Text(
                              'No pictures attached.',
                              style: TextStyle(color: Colors.grey),
                            ),
                      SizedBox(height: 24),
                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _submitForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Color.fromARGB(255, 216, 155, 41),
                                padding: EdgeInsets.symmetric(vertical: 15),
                                textStyle: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text('Save'),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                padding: EdgeInsets.symmetric(vertical: 15),
                                textStyle: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text('Close'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Display loading indicator during submission
                if (_isSubmitting)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black54,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              'Submitting Complaint...',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() => runApp(MaterialApp(
      home: ComplaintPage(),
      theme: ThemeData(
        primaryColor: Color.fromARGB(255, 216, 155, 41),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
    ));
