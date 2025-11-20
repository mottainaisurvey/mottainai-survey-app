import 'dart:convert';
import 'dart:math';

class BuildingPolygon {
  final String buildingId;
  final String? businessName;
  final String? custPhone;
  final String? customerEmail;
  final String? address;
  final String? zone;
  final String? socioEconomicGroups;
  final String geometry; // GeoJSON polygon
  final double centerLat;
  final double centerLon;
  final DateTime lastUpdated;

  BuildingPolygon({
    required this.buildingId,
    this.businessName,
    this.custPhone,
    this.customerEmail,
    this.address,
    this.zone,
    this.socioEconomicGroups,
    required this.geometry,
    required this.centerLat,
    required this.centerLon,
    required this.lastUpdated,
  });

  // Convert Web Mercator (EPSG:3857) to WGS84 (EPSG:4326)
  static Map<String, double> webMercatorToWGS84(double x, double y) {
    const double earthRadius = 6378137.0;
    final lon = (x / earthRadius) * (180 / 3.141592653589793);
    final lat = (2 * 3.141592653589793 / 4 - 2 * atan(exp(-y / earthRadius))) * (180 / 3.141592653589793);
    return {'lat': lat, 'lon': lon};
  }
  
  // From ArcGIS Feature Service response
  factory BuildingPolygon.fromArcGIS(Map<String, dynamic> feature) {
    final attributes = feature['attributes'] as Map<String, dynamic>;
    final geometry = feature['geometry'];
    
    // Convert polygon rings from Web Mercator to WGS84
    final rings = geometry['rings'] as List;
    List<List<List<double>>> convertedRings = [];
    double sumLat = 0, sumLon = 0;
    int count = 0;
    
    if (rings.isNotEmpty) {
      for (var ring in rings) {
        List<List<double>> convertedRing = [];
        for (var point in ring) {
          if (point is List && point.length >= 2) {
            // Handle both int and double from ArcGIS API
            final webMercX = (point[0] is int) ? (point[0] as int).toDouble() : point[0] as double;
            final webMercY = (point[1] is int) ? (point[1] as int).toDouble() : point[1] as double;
            final wgs84 = webMercatorToWGS84(webMercX, webMercY);
            convertedRing.add([wgs84['lon']!, wgs84['lat']!]);
            sumLon += wgs84['lon']!;
            sumLat += wgs84['lat']!;
            count++;
          }
        }
        convertedRings.add(convertedRing);
      }
    }
    
    final centerLon = count > 0 ? sumLon / count : 0.0;
    final centerLat = count > 0 ? sumLat / count : 0.0;
    
    // Create WGS84 geometry object
    final wgs84Geometry = {
      'rings': convertedRings,
      'spatialReference': {'wkid': 4326}
    };

    return BuildingPolygon(
      buildingId: attributes['building_id']?.toString() ?? '',
      businessName: attributes['business_name']?.toString(),
      custPhone: attributes['cust_phone']?.toString(),
      customerEmail: attributes['customer_email']?.toString(),
      address: attributes['address']?.toString(),
      zone: attributes['Zone']?.toString(),
      socioEconomicGroups: attributes['socio_economic_groups']?.toString(),
      geometry: jsonEncode(wgs84Geometry),
      centerLat: centerLat,
      centerLon: centerLon,
      lastUpdated: DateTime.now(),
    );
  }

  // To SQLite database
  Map<String, dynamic> toMap() {
    return {
      'buildingId': buildingId,
      'businessName': businessName,
      'custPhone': custPhone,
      'customerEmail': customerEmail,
      'address': address,
      'zone': zone,
      'socioEconomicGroups': socioEconomicGroups,
      'geometry': geometry,
      'centerLat': centerLat,
      'centerLon': centerLon,
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
    };
  }

  // From SQLite database
  factory BuildingPolygon.fromMap(Map<String, dynamic> map) {
    return BuildingPolygon(
      buildingId: map['buildingId'] as String,
      businessName: map['businessName'] as String?,
      custPhone: map['custPhone'] as String?,
      customerEmail: map['customerEmail'] as String?,
      address: map['address'] as String?,
      zone: map['zone'] as String?,
      socioEconomicGroups: map['socioEconomicGroups'] as String?,
      geometry: map['geometry'] as String,
      centerLat: map['centerLat'] as double,
      centerLon: map['centerLon'] as double,
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(map['lastUpdated'] as int),
    );
  }
}
