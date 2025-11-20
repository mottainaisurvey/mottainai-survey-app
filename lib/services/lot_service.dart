import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/company.dart';

class LotService {
  static const String _apiUrl = 'https://admin.kowope.xyz/api/trpc/lots.list';
  static const String _validateUrl = 'https://admin.kowope.xyz/api/trpc/lots.validateAccess';
  static const String _cacheKey = 'cached_lots';
  static const String _cacheTimestampKey = 'cached_lots_timestamp';
  static const String _cacheUserIdKey = 'cached_lots_user_id';
  static const Duration _cacheExpiry = Duration(hours: 24);

  /// Fetch lots from API with role-based filtering
  /// 
  /// Parameters:
  /// - userId: MongoDB ObjectId of the logged-in user
  /// 
  /// Returns:
  /// - List of lots based on user's role and company assignment
  /// - Regular users get only their company's lots
  /// - Cherry pickers and admins get all lots
  Future<List<OperationalLot>> fetchLots(String userId) async {
    try {
      // Build tRPC batch input
      final inputData = {
        '0': {
          'json': {
            'userId': userId,
          }
        }
      };

      // URL encode the input
      final encodedInput = Uri.encodeComponent(json.encode(inputData));
      final url = '$_apiUrl?batch=1&input=$encodedInput';

      print('[LotService] Fetching lots for user: $userId');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Parse tRPC batch response
        final result = data[0]['result']['data']['json'];
        final lotsJson = result['lots'] as List;
        final userRole = result['userRole'] as String;
        final totalCount = result['totalCount'] as int;
        final message = result['message'] as String;

        print('[LotService] Success: $message');
        print('[LotService] User role: $userRole');
        print('[LotService] Total lots: $totalCount');

        final lots = lotsJson.map((lot) {
          return OperationalLot(
            lotCode: lot['lotCode'] ?? '',
            lotName: lot['lotName'] ?? '',
            paytWebhook: lot['paytWebhook'] ?? '',
            monthlyWebhook: lot['monthlyWebhook'] ?? '',
            companyId: lot['companyId'] ?? '',
            companyName: lot['companyName'] ?? '',
          );
        }).toList();

        // Cache the results with user ID
        await _cacheLots(userId, lots);

        return lots;
      } else {
        throw Exception('Failed to load lots: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('[LotService] Error fetching lots: $e');

      // Try to return cached data even if expired
      final cachedLots = await _getCachedLots(userId, ignoreExpiry: true);
      if (cachedLots.isNotEmpty) {
        print('[LotService] Returning expired cache due to error');
        return cachedLots;
      }

      rethrow;
    }
  }

  /// Validate if user can access a specific lot
  /// Call this before submitting a pickup to prevent abuse
  Future<bool> validateLotAccess({
    required String userId,
    required String lotCode,
    required String companyId,
  }) async {
    try {
      final inputData = {
        '0': {
          'json': {
            'userId': userId,
            'lotCode': lotCode,
            'companyId': companyId,
          }
        }
      };

      final encodedInput = Uri.encodeComponent(json.encode(inputData));
      final url = '$_validateUrl?batch=1&input=$encodedInput';

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data[0]['result']['data']['json'];
        final hasAccess = result['hasAccess'] as bool;
        final reason = result['reason'] as String;

        print('[LotService] Access validation: $hasAccess - $reason');
        return hasAccess;
      }

      return false;
    } catch (e) {
      print('[LotService] Error validating lot access: $e');
      return false;
    }
  }

  /// Get lots with caching strategy
  Future<List<OperationalLot>> getLots(String userId, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cachedLots = await _getCachedLots(userId);
      if (cachedLots.isNotEmpty && !await _isCacheExpired()) {
        print('[LotService] Returning ${cachedLots.length} lots from cache');
        return cachedLots;
      }
    }

    // Fetch fresh data from API
    return await fetchLots(userId);
  }

  /// Cache lots to local storage
  Future<void> _cacheLots(String userId, List<OperationalLot> lots) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'userId': userId,
        'lots': lots.map((lot) => lot.toJson()).toList(),
      };
      await prefs.setString(_cacheKey, json.encode(cacheData));
      await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
      await prefs.setString(_cacheUserIdKey, userId);
      print('[LotService] Cached ${lots.length} lots for user $userId');
    } catch (e) {
      print('[LotService] Error caching lots: $e');
    }
  }

  /// Get cached lots from local storage
  Future<List<OperationalLot>> _getCachedLots(String userId, {bool ignoreExpiry = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      final timestamp = prefs.getInt(_cacheTimestampKey);
      final cachedUserId = prefs.getString(_cacheUserIdKey);

      if (cachedJson == null || timestamp == null) {
        return [];
      }

      // Check expiry
      if (!ignoreExpiry) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
        if (cacheAge > _cacheExpiry.inMilliseconds) {
          print('[LotService] Cache expired (${cacheAge ~/ 1000 ~/ 60} minutes old)');
          return [];
        }
      }

      final cacheData = json.decode(cachedJson);

      // Verify cache is for the current user
      if (cacheData['userId'] != userId || cachedUserId != userId) {
        print('[LotService] Cache is for different user, ignoring');
        return [];
      }

      final lotsJson = cacheData['lots'] as List;
      final lots = lotsJson
          .map((lot) => OperationalLot.fromJson(lot as Map<String, dynamic>))
          .toList();

      return lots;
    } catch (e) {
      print('[LotService] Error reading cached lots: $e');
      return [];
    }
  }

  /// Check if cache is expired
  Future<bool> _isCacheExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_cacheTimestampKey);

      if (timestamp == null) return true;

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();

      return now.difference(cacheTime) > _cacheExpiry;
    } catch (e) {
      return true;
    }
  }

  /// Clear cache (call on logout or role change)
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);
      await prefs.remove(_cacheUserIdKey);
      print('[LotService] Cache cleared');
    } catch (e) {
      print('[LotService] Error clearing cache: $e');
    }
  }

  /// Get lot by code
  Future<OperationalLot?> getLotByCode(String userId, String lotCode) async {
    final lots = await getLots(userId);
    try {
      return lots.firstWhere((lot) => lot.lotCode == lotCode);
    } catch (e) {
      return null;
    }
  }
}
