import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/building_polygon.dart';

class BuildingInfoPopup extends StatefulWidget {
  final BuildingPolygon polygon;
  final Function(BuildingPolygon) onConfirm;

  const BuildingInfoPopup({
    super.key,
    required this.polygon,
    required this.onConfirm,
  });

  @override
  State<BuildingInfoPopup> createState() => _BuildingInfoPopupState();
}

class _BuildingInfoPopupState extends State<BuildingInfoPopup> {
  late TextEditingController _businessNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _businessNameController = TextEditingController(text: widget.polygon.businessName ?? '');
    _phoneController = TextEditingController(text: widget.polygon.custPhone ?? '');
    _emailController = TextEditingController(text: widget.polygon.customerEmail ?? '');
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _openStreetView() async {
    final lat = widget.polygon.centerLat;
    final lon = widget.polygon.centerLon;
    
    // Try Google Maps app first with Street View
    final googleMapsUrl = Uri.parse('google.streetview:cbll=$lat,$lon');
    
    try {
      // Try to launch Google Maps Street View
      bool launched = false;
      
      if (await canLaunchUrl(googleMapsUrl)) {
        launched = await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      }
      
      // Fallback to web-based Street View if app launch fails
      if (!launched) {
        final webUrl = Uri.parse('https://www.google.com/maps/@$lat,$lon,3a,75y,0h,90t/data=!3m4!1e1!3m2!1s0!2e0');
        if (await canLaunchUrl(webUrl)) {
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not open Street View. Please install Google Maps.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening Street View: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleConfirm() {
    // Create updated polygon with edited values
    final updatedPolygon = BuildingPolygon(
      buildingId: widget.polygon.buildingId,
      businessName: _businessNameController.text.trim().isEmpty 
          ? null 
          : _businessNameController.text.trim(),
      custPhone: _phoneController.text.trim().isEmpty 
          ? null 
          : _phoneController.text.trim(),
      customerEmail: _emailController.text.trim().isEmpty 
          ? null 
          : _emailController.text.trim(),
      address: widget.polygon.address,
      zone: widget.polygon.zone,
      socioEconomicGroups: widget.polygon.socioEconomicGroups,
      geometry: widget.polygon.geometry,
      centerLat: widget.polygon.centerLat,
      centerLon: widget.polygon.centerLon,
      lastUpdated: widget.polygon.lastUpdated,
    );

    widget.onConfirm(updatedPolygon);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with Street View button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.business, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Building Information',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.streetview, color: Colors.white),
                    onPressed: _openStreetView,
                    tooltip: 'Open Street View',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Building ID (Read-only)
                    _buildReadOnlyField(
                      'Building ID',
                      widget.polygon.buildingId,
                      Icons.tag,
                      Colors.blue,
                    ),
                    const SizedBox(height: 16),

                    // Business Name (Editable)
                    _buildEditableField(
                      'Business Name',
                      _businessNameController,
                      Icons.business,
                      'Enter business name',
                    ),
                    const SizedBox(height: 16),

                    // Phone (Editable)
                    _buildEditableField(
                      'Phone Number',
                      _phoneController,
                      Icons.phone,
                      'Enter phone number',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    // Email (Editable)
                    _buildEditableField(
                      'Email Address',
                      _emailController,
                      Icons.email,
                      'Enter email address',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),

                    // Address (Read-only)
                    if (widget.polygon.address != null && widget.polygon.address!.isNotEmpty)
                      _buildReadOnlyField(
                        'Address',
                        widget.polygon.address!,
                        Icons.location_on,
                        Colors.green,
                      ),
                    if (widget.polygon.address != null && widget.polygon.address!.isNotEmpty)
                      const SizedBox(height: 16),

                    // Zone (Read-only)
                    if (widget.polygon.zone != null && widget.polygon.zone!.isNotEmpty)
                      _buildReadOnlyField(
                        'Zone',
                        widget.polygon.zone!,
                        Icons.map,
                        Colors.orange,
                      ),
                    if (widget.polygon.zone != null && widget.polygon.zone!.isNotEmpty)
                      const SizedBox(height: 16),

                    // Socio-Economic Group (Read-only)
                    if (widget.polygon.socioEconomicGroups != null && 
                        widget.polygon.socioEconomicGroups!.isNotEmpty)
                      _buildReadOnlyField(
                        'Socio-Economic Group',
                        widget.polygon.socioEconomicGroups!,
                        Icons.group,
                        Colors.purple,
                      ),
                  ],
                ),
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _handleConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Use This Building'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon, Color iconColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller,
    IconData icon,
    String hint, {
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.all(12),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
