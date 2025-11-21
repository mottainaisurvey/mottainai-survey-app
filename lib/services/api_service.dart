import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/user.dart';
import '../models/pickup_submission.dart';

class ApiService {
  // IMPORTANT: Change this to your server's IP address
  static const String baseUrl = 'http://172.232.24.180:3000';
  
  String? _token;

  void setToken(String token) {
    _token = token;
  }

  String? getToken() {
    return _token;
  }

  void clearToken() {
    _token = null;
  }

  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = _token!;
    }
    return headers;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // Password needs to be base64 encoded as per backend requirement
      final encodedPassword = base64.encode(utf8.encode(password));
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/mobile/users/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': encodedPassword,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['token'];
        return {
          'success': true,
          'token': data['token'],
          'user': User.fromJson(data['user']),
        };
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Login failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> getMe() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/mobile/users/me'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'user': User.fromJson(data['user']),
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get user info',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> submitPickup(
    PickupSubmission pickup,
    File firstPhotoFile,
    File secondPhotoFile,
    String userFullName,
    String userPhoneNumber,
  ) async {
    try {
      // Use /survey endpoint with correct data format
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/survey'),
      );

      // Add authorization header
      if (_token != null) {
        request.headers['Authorization'] = _token!;
      }

      // Map to backend expected format
      final surveyData = {
        'feature': {
          'attributes': {
            'building_id': pickup.buildingId,
            'customer_type': pickup.customerType,
            'full_name': userFullName,
            'phone_number': userPhoneNumber,
            'bin_qty_per_pickup': pickup.binQuantity,
            'bin_type': pickup.binType,
            'pickup_date': pickup.pickUpDate,
            'form_id': pickup.formId,
            'supervisor_id': pickup.supervisorId,
            'wheelie_bin_type': pickup.wheelieBinType,
            'incident_report': pickup.incidentReport,
            'user_id': pickup.userId,
            'latitude': pickup.latitude,
            'longitude': pickup.longitude,
            'company_id': pickup.companyId,
            'company_name': pickup.companyName,
            'lot_code': pickup.lotCode,
            'lot_name': pickup.lotName,
          }
        }
      };

      // Send as JSON body
      request.fields['data'] = json.encode(surveyData);

      // Add photo files
      request.files.add(await http.MultipartFile.fromPath(
        'firstPhoto',
        firstPhotoFile.path,
        contentType: MediaType('image', 'jpeg'),
      ));

      request.files.add(await http.MultipartFile.fromPath(
        'secondPhoto',
        secondPhotoFile.path,
        contentType: MediaType('image', 'jpeg'),
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': 'Pickup submitted successfully',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to submit pickup: ${response.body}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  Future<bool> checkConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
