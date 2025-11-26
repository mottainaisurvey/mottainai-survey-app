import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as loc;
import '../models/building_polygon.dart';
import '../services/polygon_cache_service.dart';
import '../services/api_service.dart';
import 'building_info_popup.dart';

class EnhancedLocationMap extends StatefulWidget {
  final Function(double lat, double lon) onLocationSelected;
  final Function(BuildingPolygon)? onBuildingSelected;
  final double? initialLat;
  final double? initialLon;

  const EnhancedLocationMap({
    super.key,
    required this.onLocationSelected,
    this.onBuildingSelected,
    this.initialLat,
    this.initialLon,
  });

  @override
  State<EnhancedLocationMap> createState() => _EnhancedLocationMapState();
}

class _EnhancedLocationMapState extends State<EnhancedLocationMap> {
  final MapController _mapController = MapController();
  final PolygonCacheService _polygonService = PolygonCacheService();
  final ApiService _apiService = ApiService();

  LatLng? _selectedLocation;
  LatLng? _currentLocation;
  bool _isLoading = false; // Changed to false to remove blocking loader
  bool _isLoadingPolygons = false;
  String? _error;

  List<BuildingPolygon> _cachedPolygons = [];
  BuildingPolygon? _selectedPolygon;
  String? _cacheInfo;
  Map<String, String> _customerLabelsCache = {}; // buildingId -> labels

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      loc.Location location = loc.Location();

      // Check if location services are enabled
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          setState(() {
            _error = 'Location services are disabled. Please enable them.';
            _isLoading = false;
          });
          return;
        }
      }

      // Check location permissions
      loc.PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == loc.PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != loc.PermissionStatus.granted) {
          setState(() {
            _error = 'Location permission denied';
            _isLoading = false;
          });
          return;
        }
      }

      // Get current location
      loc.LocationData locationData = await location.getLocation();

      setState(() {
        _currentLocation =
            LatLng(locationData.latitude!, locationData.longitude!);

        // Use initial location if provided, otherwise use current location
        if (widget.initialLat != null && widget.initialLon != null) {
          _selectedLocation = LatLng(widget.initialLat!, widget.initialLon!);
        } else {
          _selectedLocation = _currentLocation;
          widget.onLocationSelected(
              locationData.latitude!, locationData.longitude!);
        }

        _isLoading = false;
      });

      // Move map to location after first frame
      if (_selectedLocation != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _mapController.move(_selectedLocation!, 19.5);
          }
        });
      }

      // Load polygons for current location
      await _loadPolygonsForCurrentLocation();
    } catch (e) {
      setState(() {
        _error = 'Failed to get location: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPolygonsForCurrentLocation() async {
    if (_currentLocation == null) return;

    setState(() {
      _isLoadingPolygons = true;
    });

    try {
      // First, try to load from cache
      final cachedPolygons =
          await _polygonService.getCachedPolygonsNearLocation(
        lat: _currentLocation!.latitude,
        lon: _currentLocation!.longitude,
        radiusKm: 5.0,
      );

      setState(() {
        _cachedPolygons = cachedPolygons;
      });

      // Fetch customer labels for all polygons (non-blocking)
      _fetchCustomerLabelsForPolygons(cachedPolygons);

      print('Loaded ${cachedPolygons.length} cached polygons');
      if (cachedPolygons.isNotEmpty) {
        print(
            'First polygon: ${cachedPolygons[0].buildingId} at (${cachedPolygons[0].centerLat}, ${cachedPolygons[0].centerLon})');
      }

      // Get cache stats
      final stats = await _polygonService.getCacheStats();
      setState(() {
        _cacheInfo =
            '${stats.polygonCount} buildings cached • ${stats.lastUpdatedText}';
      });

      // If cache is empty or needs refresh, sync from ArcGIS
      if (cachedPolygons.isEmpty || await _polygonService.needsRefresh()) {
        await _syncPolygons();
      } else {
        setState(() {
          _isLoadingPolygons = false;
        });
      }
    } catch (e) {
      print('Error loading polygons: $e');
      setState(() {
        _isLoadingPolygons = false;
      });
    }
  }

  Future<void> _syncPolygons() async {
    if (_currentLocation == null) return;

    setState(() {
      _isLoadingPolygons = true;
    });

    try {
      final result = await _polygonService.syncPolygonsForLocation(
        lat: _currentLocation!.latitude,
        lon: _currentLocation!.longitude,
        radiusKm: 5.0,
      );

      if (result.success) {
        // Reload polygons from cache
        final cachedPolygons =
            await _polygonService.getCachedPolygonsNearLocation(
          lat: _currentLocation!.latitude,
          lon: _currentLocation!.longitude,
          radiusKm: 5.0,
        );

        setState(() {
          _cachedPolygons = cachedPolygons;
        });

        // Update cache info
        final stats = await _polygonService.getCacheStats();
        setState(() {
          _cacheInfo =
              '${stats.polygonCount} buildings cached • ${stats.lastUpdatedText}';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingPolygons = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      loc.Location location = loc.Location();
      loc.LocationData locationData = await location.getLocation();

      setState(() {
        _currentLocation =
            LatLng(locationData.latitude!, locationData.longitude!);
        _selectedLocation = _currentLocation;
      });

      widget.onLocationSelected(
          locationData.latitude!, locationData.longitude!);

      // Safely move map after ensuring it's rendered
      if (mounted && _mapController.mapEventStream != null) {
        _mapController.move(_currentLocation!, 17.0);
      }

      // Reload polygons for new location
      await _loadPolygonsForCurrentLocation();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng position) {
    // Check if tap is on a polygon
    BuildingPolygon? tappedPolygon = _findPolygonAtPoint(position);

    if (tappedPolygon != null) {
      // Show building info popup
      _showBuildingInfoPopup(tappedPolygon);
    } else {
      // Regular location selection
      setState(() {
        _selectedLocation = position;
        _selectedPolygon = null;
      });
      widget.onLocationSelected(position.latitude, position.longitude);
    }
  }

  BuildingPolygon? _findPolygonAtPoint(LatLng point) {
    for (var polygon in _cachedPolygons) {
      if (_isPointInPolygon(point, polygon)) {
        return polygon;
      }
    }
    return null;
  }

  bool _isPointInPolygon(LatLng point, BuildingPolygon polygon) {
    try {
      // Parse geometry JSON
      final geometryJson = jsonDecode(polygon.geometry);
      final rings = geometryJson['rings'] as List;

      if (rings.isEmpty) return false;

      // Use first ring (exterior boundary)
      final ring = rings[0] as List;

      // Ray casting algorithm for point-in-polygon test
      bool inside = false;
      int j = ring.length - 1;

      for (int i = 0; i < ring.length; i++) {
        final xi = ring[i][0] as double;
        final yi = ring[i][1] as double;
        final xj = ring[j][0] as double;
        final yj = ring[j][1] as double;

        final intersect = ((yi > point.latitude) != (yj > point.latitude)) &&
            (point.longitude <
                (xj - xi) * (point.latitude - yi) / (yj - yi) + xi);

        if (intersect) inside = !inside;
        j = i;
      }

      return inside;
    } catch (e) {
      print('Error checking point in polygon: $e');
      return false;
    }
  }

  // Fetch customer labels for all polygons
  Future<void> _fetchCustomerLabelsForPolygons(
      List<BuildingPolygon> polygons) async {
    for (var polygon in polygons) {
      try {
        final result =
            await _apiService.getBuildingCustomers(polygon.buildingId);
        if (result['success'] == true && result['existingCustomers'] != null) {
          final customers = result['existingCustomers'] as List;
          if (customers.isNotEmpty) {
            final labels = customers.map((c) => c['label'] as String).join(',');
            setState(() {
              _customerLabelsCache[polygon.buildingId] = labels;
            });
          }
        }
      } catch (e) {
        print('Error fetching customer labels for ${polygon.buildingId}: $e');
      }
    }
  }

  // Show existing customers dialog when tapping green label
  void _showExistingCustomersDialog(BuildingPolygon polygon) async {
    try {
      // Fetch existing customers
      final result = await _apiService.getBuildingCustomers(polygon.buildingId);

      if (result['success'] != true || result['existingCustomers'] == null) {
        // Fallback to direct selection if API fails
        _selectPolygonDirectly(polygon);
        return;
      }

      final existingCustomers = result['existingCustomers'] as List;

      if (existingCustomers.isEmpty) {
        // No customers found, go directly to form
        _selectPolygonDirectly(polygon);
        return;
      }

      // Show dialog with existing customers
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.people, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'EXISTING CUSTOMERS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Building: ${polygon.buildingId}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This building has ${existingCustomers.length} registered customer(s):',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select a customer to add pickup:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              ...existingCustomers
                  .map((customer) => InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          // Navigate to form with this customer's data
                          _selectPolygonDirectly(polygon);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: customer['label']
                                          .toString()
                                          .startsWith('R')
                                      ? Colors.blue.shade700
                                      : Colors.orange.shade700,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  customer['label'] as String,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customer['name'] as String,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      customer['email'] as String,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios,
                                  size: 16, color: Colors.grey.shade400),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error showing existing customers dialog: $e');
      // Fallback to direct selection
      _selectPolygonDirectly(polygon);
    }
  }

  // Direct selection when tapping label - no confirmation
  void _selectPolygonDirectly(BuildingPolygon polygon) {
    showDialog(
      context: context,
      builder: (context) => BuildingInfoPopup(
        polygon: polygon,
        onConfirm: (updatedPolygon) {
          setState(() {
            _selectedPolygon = updatedPolygon;
            _selectedLocation =
                LatLng(updatedPolygon.centerLat, updatedPolygon.centerLon);
          });

          widget.onLocationSelected(
              updatedPolygon.centerLat, updatedPolygon.centerLon);
          widget.onBuildingSelected?.call(updatedPolygon);
        },
      ),
    );
  }

  // Show confirmation dialog when tapping polygon (not label)
  void _showBuildingInfoPopup(BuildingPolygon polygon) async {
    // Check if building has existing customers
    try {
      final result = await _apiService.checkBuilding(polygon.buildingId);

      if (result['success'] == true && result['hasCustomers'] == true) {
        // Show duplicate detection dialog
        final existingCustomers = result['existingCustomers'] as List;
        final customerCount = result['customerCount'] as int;

        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      const Icon(Icons.warning, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'ADD NEW CUSTOMER',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'WARNING: Existing Customers',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This building already has $customerCount registered customer(s):',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ...existingCustomers
                    .map((customer) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: customer['label']
                                          .toString()
                                          .startsWith('R')
                                      ? Colors.blue.shade700
                                      : Colors.orange.shade700,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  customer['label'] as String,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customer['name'] as String,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      customer['email'] as String,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.help_outline,
                          color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Are you sure you want to create a NEW customer account for this building?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 15),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text(
                  'Yes, Add New Customer',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );

        if (shouldContinue != true) {
          return; // User cancelled
        }
      }
    } catch (e) {
      print('Error checking building: $e');
      // Continue anyway if check fails
    }

    // Show building info popup
    showDialog(
      context: context,
      builder: (context) => BuildingInfoPopup(
        polygon: polygon,
        onConfirm: (updatedPolygon) {
          setState(() {
            _selectedPolygon = updatedPolygon;
            _selectedLocation =
                LatLng(updatedPolygon.centerLat, updatedPolygon.centerLon);
          });

          widget.onLocationSelected(
              updatedPolygon.centerLat, updatedPolygon.centerLon);
          widget.onBuildingSelected?.call(updatedPolygon);
        },
      ),
    );
  }

  // Generate a consistent color for each polygon based on building ID
  Color _getPolygonColor(String buildingId) {
    // Use hash code to generate a consistent color
    final hash = buildingId.hashCode;

    // Define a palette of distinct, vibrant colors
    final colors = [
      const Color(0xFFE91E63), // Pink
      const Color(0xFF9C27B0), // Purple
      const Color(0xFF673AB7), // Deep Purple
      const Color(0xFF3F51B5), // Indigo
      const Color(0xFF2196F3), // Blue
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFF009688), // Teal
      const Color(0xFF4CAF50), // Green
      const Color(0xFF8BC34A), // Light Green
      const Color(0xFFCDDC39), // Lime
      const Color(0xFFFFEB3B), // Yellow
      const Color(0xFFFFC107), // Amber
      const Color(0xFFFF9800), // Orange
      const Color(0xFFFF5722), // Deep Orange
      const Color(0xFFF44336), // Red
    ];

    // Select color based on hash
    return colors[hash.abs() % colors.length];
  }

  // Calculate center point of a polygon for label placement
  LatLng _getPolygonCenter(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);

    double sumLat = 0;
    double sumLon = 0;

    for (var point in points) {
      sumLat += point.latitude;
      sumLon += point.longitude;
    }

    return LatLng(sumLat / points.length, sumLon / points.length);
  }

  List<Polygon> _buildPolygonOverlays() {
    print('Building ${_cachedPolygons.length} polygon overlays...');
    if (_cachedPolygons.isNotEmpty) {
      print(
          'Sample geometry format: ${_cachedPolygons[0].geometry.substring(0, min(100, _cachedPolygons[0].geometry.length))}...');
    }

    return _cachedPolygons
        .map((buildingPolygon) {
          try {
            // Parse geometry JSON
            final geometryJson = jsonDecode(buildingPolygon.geometry);
            final rings = geometryJson['rings'] as List;

            if (rings.isEmpty) return null;

            // Convert first ring to LatLng points
            final ring = rings[0] as List;
            final points = ring.map((coord) {
              // Handle both int and double coordinates
              final lat = (coord[1] is int)
                  ? (coord[1] as int).toDouble()
                  : coord[1] as double;
              final lon = (coord[0] is int)
                  ? (coord[0] as int).toDouble()
                  : coord[0] as double;
              return LatLng(lat, lon);
            }).toList();

            // Determine if this polygon is selected
            final isSelected =
                _selectedPolygon?.buildingId == buildingPolygon.buildingId;

            // Generate a unique color for each polygon based on building ID
            final polygonColor = _getPolygonColor(buildingPolygon.buildingId);

            print(
                'Polygon ${buildingPolygon.buildingId}: ${points.length} points, first point: ${points.isNotEmpty ? points[0] : "none"}');

            return Polygon(
              points: points,
              color: isSelected
                  ? Colors.blue.withOpacity(0.4)
                  : polygonColor.withOpacity(
                      0.3), // Semi-transparent fill with unique color
              borderColor: isSelected
                  ? Colors.blue
                  : polygonColor, // Colored border matching the fill
              borderStrokeWidth: isSelected ? 4.0 : 2.5,
              isFilled: true,
            );
          } catch (e) {
            print(
                'Error building polygon overlay for ${buildingPolygon.buildingId}: $e');
            print('Geometry: ${buildingPolygon.geometry}');
            return null;
          }
        })
        .whereType<Polygon>()
        .toList();
  }

  // Build text labels for polygons showing business names
  List<Marker> _buildPolygonLabels() {
    return _cachedPolygons
        .map((buildingPolygon) {
          try {
            // Parse geometry JSON
            final geometryJson = jsonDecode(buildingPolygon.geometry);
            final rings = geometryJson['rings'] as List;

            if (rings.isEmpty) return null;

            // Convert first ring to LatLng points
            final ring = rings[0] as List;
            final points = ring.map((coord) {
              final lat = (coord[1] is int)
                  ? (coord[1] as int).toDouble()
                  : coord[1] as double;
              final lon = (coord[0] is int)
                  ? (coord[0] as int).toDouble()
                  : coord[0] as double;
              return LatLng(lat, lon);
            }).toList();

            // Calculate center point for label
            final center = _getPolygonCenter(points);

            // Get business name from attributes (fallback to building ID if not available)
            final businessName =
                buildingPolygon.businessName ?? buildingPolygon.buildingId;

            // Get customer labels from cache
            final customerLabels =
                _customerLabelsCache[buildingPolygon.buildingId];

            // Build label text: "buildingId" or "buildingId-R1,R2,B1"
            final labelText =
                customerLabels != null && customerLabels.isNotEmpty
                    ? '$businessName-$customerLabels'
                    : businessName;

            // Determine label color based on whether building has existing customers
            final hasCustomers =
                customerLabels != null && customerLabels.isNotEmpty;
            final labelColor =
                hasCustomers ? Colors.green.shade700 : Colors.blue.shade700;
            final labelIcon = hasCustomers ? '📋' : '';

            return Marker(
              point: center,
              width: hasCustomers ? 140 : 120, // Wider for customer labels
              height: 36, // Slightly taller for better visibility
              child: GestureDetector(
                behavior: HitTestBehavior.opaque, // Consume tap events
                onTap: () {
                  // Different behavior for existing customers vs empty buildings
                  if (hasCustomers) {
                    _showExistingCustomersDialog(buildingPolygon);
                  } else {
                    _selectPolygonDirectly(buildingPolygon);
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: labelColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      labelText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10, // Larger for better visibility
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 3,
                            color: Colors.black,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ),
              ),
            );
          } catch (e) {
            print(
                'Error building polygon label for ${buildingPolygon.buildingId}: $e');
            return null;
          }
        })
        .whereType<Marker>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 400,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Getting your location...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        height: 400,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _error = null;
                    });
                    _initializeLocation();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 400,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter:
                        _selectedLocation ?? const LatLng(6.5795, 3.3549),
                    initialZoom: 18.5,
                    onTap: _onMapTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                      userAgentPackageName: 'com.mottainai.survey',
                      maxZoom: 19,
                    ),
                    TileLayer(
                      urlTemplate:
                          'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
                      userAgentPackageName: 'com.mottainai.survey',
                      maxZoom: 19,
                    ),
                    // Polygon overlays
                    PolygonLayer(
                      polygons: _buildPolygonOverlays(),
                    ),
                    // Polygon labels
                    MarkerLayer(
                      markers: _buildPolygonLabels(),
                    ),
                    // Selected location marker
                    if (_selectedLocation != null && _selectedPolygon == null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLocation!,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    // Current location marker
                    if (_currentLocation != null &&
                        _currentLocation != _selectedLocation)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentLocation!,
                            width: 30,
                            height: 30,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.3),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.blue, width: 2),
                              ),
                              child: const Icon(
                                Icons.my_location,
                                color: Colors.blue,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                // Loading indicator for polygons
                if (_isLoadingPolygons)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Loading buildings...'),
                        ],
                      ),
                    ),
                  ),
                // Cache info
                if (!_isLoadingPolygons && _cacheInfo != null)
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 60,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.business,
                              size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _cacheInfo!,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Current location button
                Positioned(
                  right: 10,
                  bottom: 70,
                  child: FloatingActionButton(
                    mini: true,
                    onPressed: _getCurrentLocation,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.my_location, color: Colors.blue),
                  ),
                ),
                // Refresh polygons button
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: FloatingActionButton(
                    mini: true,
                    onPressed: _isLoadingPolygons ? null : _syncPolygons,
                    backgroundColor: Colors.white,
                    child: _isLoadingPolygons
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, color: Colors.green),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Selected building info
        if (_selectedPolygon != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.business, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Building: ${_selectedPolygon!.buildingId}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_selectedPolygon!.businessName != null)
                        Text(
                          _selectedPolygon!.businessName!,
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else if (_selectedLocation != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}, '
                    'Lon: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
