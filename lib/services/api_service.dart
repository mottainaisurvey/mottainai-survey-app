import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/pickup_submission.dart';

class ApiService {
  // IMPORTANT: Change this to your server's IP address
  static const String baseUrl = 'http://172.232.24.180:3003';
  
  String? _token;
  DateTime? _lastActivityTime;
  static const Duration inactivityTimeout = Duration(minutes: 20);

  void setToken(String token) {
    _token = token;
    _updateActivity();
  }

  void _updateActivity() {
    _lastActivityTime = DateTime.now();
  }

  bool isInactive() {
    if (_lastActivityTime == null) return false;
    return DateTime.now().difference(_lastActivityTime!) > inactivityTimeout;
  }

  Future<void> _handleTokenRefresh(http.Response response) async {
    final newToken = response.headers['x-new-token'];
    if (newToken != null && newToken.isNotEmpty) {
      print('[ApiService] Token refreshed by server');
      _token = newToken;
      // Save new token to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', newToken);
    }
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
        Uri.parse('$baseUrl/users/login'),
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
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/forms/submit'),
      );

      // Add authorization header
      if (_token != null) {
        request.headers['Authorization'] = _token!;
      }

      // Add form fields
      request.fields['formId'] = pickup.formId;
      request.fields['supervisorId'] = pickup.supervisorId;
      request.fields['customerType'] = pickup.customerType;
      request.fields['binType'] = pickup.binType;
      if (pickup.wheelieBinType != null) {
        request.fields['wheelieBinType'] = pickup.wheelieBinType!;
      }
      request.fields['binQuantity'] = pickup.binQuantity.toString();
      request.fields['buildingId'] = pickup.buildingId;
      request.fields['pickUpDate'] = pickup.pickUpDate;
      if (pickup.incidentReport != null) {
        request.fields['incidentReport'] = pickup.incidentReport!;
      }
      request.fields['userId'] = pickup.userId;

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

      // Update activity timestamp
      _updateActivity();

      // Check for token refresh
      await _handleTokenRefresh(response);

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
