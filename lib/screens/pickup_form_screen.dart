import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../providers/auth_provider.dart';
import '../providers/sync_provider.dart';
import '../models/pickup_submission.dart';
import '../database/database_helper.dart';
import '../widgets/location_map_picker.dart';

class PickupFormScreen extends StatefulWidget {
  const PickupFormScreen({super.key});

  @override
  State<PickupFormScreen> createState() => _PickupFormScreenState();
}

class _PickupFormScreenState extends State<PickupFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supervisorIdController = TextEditingController();
  final _buildingIdController = TextEditingController();
  final _binQuantityController = TextEditingController();
  final _incidentReportController = TextEditingController();
  
  String _customerType = 'Residential';
  String _binType = '10 CBM SKIP BIN';
  String? _wheelieBinType;
  DateTime _pickUpDate = DateTime.now();
  File? _firstPhoto;
  File? _secondPhoto;
  bool _isSubmitting = false;
  double? _latitude;
  double? _longitude;

  final List<String> _customerTypes = ['Residential', 'Commercial'];
  final List<String> _binTypes = [
    '10 CBM SKIP BIN',
    '6CBM SKIP BIN',
    '240 LITRE WHEELIE BIN',
    '120 LITRE WHEELIE BIN',
  ];
  final List<String> _wheelieBinTypes = ['Residential', 'Commercial'];

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _supervisorIdController.dispose();
    _buildingIdController.dispose();
    _binQuantityController.dispose();
    _incidentReportController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isFirst) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        // Save to app directory
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(image.path)}';
        final savedImage = File('${appDir.path}/$fileName');
        await File(image.path).copy(savedImage.path);

        setState(() {
          if (isFirst) {
            _firstPhoto = savedImage;
          } else {
            _secondPhoto = savedImage;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _pickUpDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _pickUpDate) {
      setState(() {
        _pickUpDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_firstPhoto == null || _secondPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture both photos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set pickup location on map'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);

      final pickup = PickupSubmission(
        formId: 'default_form_id', // You can make this dynamic if needed
        supervisorId: _supervisorIdController.text.trim(),
        customerType: _customerType,
        binType: _binType,
        wheelieBinType: _wheelieBinType,
        binQuantity: int.parse(_binQuantityController.text.trim()),
        buildingId: _buildingIdController.text.trim(),
        pickUpDate: DateFormat('MMM dd, yyyy').format(_pickUpDate),
        firstPhoto: _firstPhoto!.path,
        secondPhoto: _secondPhoto!.path,
        incidentReport: _incidentReportController.text.trim().isEmpty
            ? null
            : _incidentReportController.text.trim(),
        userId: authProvider.user!.id,
        latitude: _latitude,
        longitude: _longitude,
        createdAt: DateTime.now().toIso8601String(),
      );

      // Save to local database
      await DatabaseHelper.instance.createPickup(pickup);
      await syncProvider.incrementUnsyncedCount();

      if (mounted) {
        // Try to sync immediately if online
        syncProvider.syncPendingPickups();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pickup saved! Will sync when online.'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save pickup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Pickup'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Supervisor ID
            TextFormField(
              controller: _supervisorIdController,
              decoration: InputDecoration(
                labelText: 'Supervisor ID *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.badge),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter supervisor ID';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Building ID
            TextFormField(
              controller: _buildingIdController,
              decoration: InputDecoration(
                labelText: 'Building ID *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.business),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter building ID';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Customer Type
            DropdownButtonFormField<String>(
              value: _customerType,
              decoration: InputDecoration(
                labelText: 'Customer Type *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.person),
              ),
              items: _customerTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _customerType = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // Bin Type
            DropdownButtonFormField<String>(
              value: _binType,
              decoration: InputDecoration(
                labelText: 'Bin Type *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.delete),
              ),
              items: _binTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _binType = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // Wheelie Bin Type (optional)
            if (_binType.contains('WHEELIE'))
              Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _wheelieBinType,
                    decoration: InputDecoration(
                      labelText: 'Wheelie Bin Type',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.category),
                    ),
                    items: _wheelieBinTypes.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _wheelieBinType = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            // Bin Quantity
            TextFormField(
              controller: _binQuantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Bin Quantity *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.numbers),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter bin quantity';
                }
                if (int.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Pick Up Date
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Pick Up Date *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.calendar_today),
                ),
                child: Text(
                  DateFormat('MMM dd, yyyy').format(_pickUpDate),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Location Map
            const Text(
              'Current Location *',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please click on the current location icon (radio button)',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            LocationMapPicker(
              onLocationSelected: (lat, lon) {
                setState(() {
                  _latitude = lat;
                  _longitude = lon;
                });
              },
              initialLat: _latitude,
              initialLon: _longitude,
            ),
            const SizedBox(height: 16),

            // First Photo
            _buildPhotoSection(
              title: 'First Photo *',
              photo: _firstPhoto,
              onTap: () => _pickImage(true),
            ),
            const SizedBox(height: 16),

            // Second Photo
            _buildPhotoSection(
              title: 'Second Photo *',
              photo: _secondPhoto,
              onTap: () => _pickImage(false),
            ),
            const SizedBox(height: 16),

            // Incident Report
            TextFormField(
              controller: _incidentReportController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Incident Report (Optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.report),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Submit Pickup',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Info Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your pickup will be saved locally and synced when you have internet connection.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection({
    required String title,
    required File? photo,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade100,
            ),
            child: photo == null
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'Tap to capture photo',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      photo,
                      fit: BoxFit.cover,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
