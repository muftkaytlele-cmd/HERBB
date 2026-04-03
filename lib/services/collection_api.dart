// lib/services/collection_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/services/backend_auth_service.dart';

class CollectionApi {
  /// Creates a collection record.
  /// Returns event id string if available on success, otherwise throws.
  static Future<String?> createCollection({
    required String herbType,
    required int quantity,
    required String unit,
    required String collectionDate, // YYYY-MM-DD
    required String location,
    double? latitude,
    double? longitude,
    Map<String, dynamic>? extra,
  }) async {
    final token = await BackendAuthService.getValidToken();
    final uri = Uri.parse('${BackendAuthService.apiBaseUrl}/api/v1/collections');

    final body = {
      "species": herbType,
      "quantity": quantity,
      "unit": unit,
      "harvestDate": collectionDate,
      "location": location,
      if (latitude != null) "latitude": latitude,
      if (longitude != null) "longitude": longitude,
    };

    // Merge extras if present (moisture, temperature, etc.)
    if (extra != null) {
      body.addAll(extra.map((k, v) => MapEntry(k, v)));
    }

    // Normalize app-side aliases to backend expected keys.
    if (body.containsKey('imagePaths') && !body.containsKey('images')) {
      body['images'] = body.remove('imagePaths');
    }
    if (body.containsKey('weatherCondition') && !body.containsKey('weatherConditions')) {
      body['weatherConditions'] = body.remove('weatherCondition');
    }

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final decoded = jsonDecode(response.body);
        // try common id fields
        if (decoded is Map<String, dynamic>) {
          return decoded['id']?.toString() ?? decoded['eventId']?.toString() ?? decoded['_id']?.toString();
        }
      } catch (_) {
        // if can't decode, just return null
      }
      return null;
    } else {
      // throw with server response body to help debugging
      throw Exception('API ${response.statusCode}: ${response.body}');
    }
  }
}
